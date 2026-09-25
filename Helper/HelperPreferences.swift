//
//  HelperPreferences.swift
//  com.github.macadmins.SupportCompanion.helper
//

import Foundation

/// Reads the settings that decide what the helper will do, from sources only an administrator can write.
///
/// The app has its own copy of this logic in `TrustedPreferences`, but the app's copy only decides what
/// to *offer*. Anything that runs as root is decided here, because a client can be any build of the app
/// and its view of the preferences is not evidence of anything.
///
/// Running as root also means `CFPreferences` cannot be used the way the app uses it: the helper is not
/// the logged-in user, so it would never see a configuration profile scoped to that user. The files are
/// read directly instead, in the order a managed setting would win:
///
/// 1. `/Library/Managed Preferences/<user>/<domain>.plist` — profile scoped to the connecting user
/// 2. `/Library/Managed Preferences/<domain>.plist` — profile scoped to the device
///
/// `/Library/Preferences/<domain>.plist` is deliberately **not** among them. Every setting this type
/// supplies decides something privileged — who may hold administrator rights, which commands run as
/// root, which installers are allowed — and that file is one any process already running as root may
/// write, with nothing to correct it afterwards. A single root moment would become a permanent grant
/// of all three. A managed preference cannot be forged that way for long: the MDM owns those files
/// and puts them back, which is the same reasoning behind re-reading the admin allowlist on a timer.
///
/// For development, put the plist in `/Library/Managed Preferences/` rather than reaching for the
/// local path; root can write there directly and the helper will read it.
enum HelperPreferences {

    private static let domain = "com.github.macadmins.SupportCompanion"

    /// Account names that are safe to put in a path.
    ///
    /// The name comes from `getpwuid`, which is trustworthy for local accounts — but on a
    /// directory-bound Mac it comes from whatever the directory service returns, and a name
    /// containing `/` or `..` would redirect the read to a file of somebody else's choosing.
    private static func isUsable(_ userName: String) -> Bool {
        !userName.isEmpty
            && userName != "."
            && userName != ".."
            // ASCII deliberately, matching what the comment claims. `isLetter` and `isNumber` are
            // Unicode-wide, which is harmless here but says something broader than it means.
            && userName.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-") }
    }

    private static func searchPaths(forUser userName: String?) -> [String] {
        var paths: [String] = []

        if let userName, isUsable(userName) {
            paths.append("/Library/Managed Preferences/\(userName)/\(domain).plist")
        } else if let userName, !userName.isEmpty {
            Logger.shared.logError("Ignoring the user-scoped preferences path: '\(userName)' is not a usable account name")
        }

        paths.append("/Library/Managed Preferences/\(domain).plist")

        return paths
    }

    /// The local file this type used to read, kept only so that finding settings in it can be said
    /// out loud rather than silently ignored.
    private static var unmanagedPath: String { "/Library/Preferences/\(domain).plist" }

    /// Warn when a setting lives somewhere that is no longer honoured.
    ///
    /// Dropping the local path is a behaviour change for anyone who configured it with a tool other
    /// than an MDM. Silently falling back to defaults would look like the feature breaking for no
    /// reason, so the reason is logged.
    private static func warnIfPresentUnmanaged(_ key: String) {
        guard let plist = contents(ofPlistAt: unmanagedPath), plist[key] != nil else { return }

        Logger.shared.logError(
            "Ignoring '\(key)' in \(unmanagedPath): settings that grant privileges are only read from a configuration profile. Deliver it through your MDM."
        )
    }

    /// Load a preference file, ignoring any that is not owned by root.
    ///
    /// All three directories are root-owned, so a non-root owner means the file predates that or was
    /// planted while something was misconfigured. Either way it is not an administrator's intent.
    private static func contents(ofPlistAt path: String) -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)

            guard let owner = attributes[.ownerAccountID] as? NSNumber, owner.uint32Value == 0 else {
                Logger.shared.logError("Ignoring \(path): not owned by root")
                return nil
            }

            // Root-owned is not the same as only root-writable. The directories above make this
            // unreachable today, which is exactly why the check belongs here rather than being
            // assumed from somewhere else.
            if let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value,
               permissions & 0o022 != 0 {
                Logger.shared.logError("Ignoring \(path): writable by group or other")
                return nil
            }
        } catch {
            Logger.shared.logError("Unable to check ownership of \(path): \(error.localizedDescription)")
            return nil
        }

        guard
            let data = FileManager.default.contents(atPath: path),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else {
            Logger.shared.logError("Unable to read \(path) as a property list")
            return nil
        }

        return plist
    }

    static func object(forKey key: String, forUser userName: String?) -> Any? {
        for path in searchPaths(forUser: userName) {
            if let value = contents(ofPlistAt: path)?[key] {
                return value
            }
        }

        warnIfPresentUnmanaged(key)

        return nil
    }

    static func bool(forKey key: String, default defaultValue: Bool, forUser userName: String?) -> Bool {
        let value = object(forKey: key, forUser: userName)
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? defaultValue
    }

    static func int(forKey key: String, default defaultValue: Int, forUser userName: String?) -> Int {
        let value = object(forKey: key, forUser: userName)
        return (value as? Int) ?? (value as? NSNumber)?.intValue ?? defaultValue
    }

    // MARK: Admin allowlist

    /// Whether to take administrator rights from accounts the allowlist does not account for.
    ///
    /// Read device-scoped, with no user: reconciliation runs at startup and on a timer, when there is
    /// no connecting user to attribute it to. These keys must come from a device-scoped profile.
    static var enforceAdminAllowlist: Bool {
        bool(forKey: "EnforceAdminAllowlist", default: false, forUser: nil)
    }

    /// Accounts that may hold administrator rights without the helper having granted them.
    ///
    /// `nil` when the key is absent or is not a list of strings, which is different from an empty
    /// list. An empty list is a coherent policy — nobody is permanently an administrator, every
    /// administrator is a live elevation. A missing key is a half-finished configuration, and acting
    /// on it would demote every administrator on the Mac.
    static var permanentAdmins: Set<String>? {
        guard let names = object(forKey: "PermanentAdmins", forUser: nil) as? [String] else { return nil }
        return Set(names)
    }

    /// The `Command` of an administrator-defined action, or `nil` when there is no such action or it is
    /// not marked `IsPrivileged`.
    static func privilegedActionCommand(named name: String, forUser userName: String?) -> String? {
        guard let actions = object(forKey: "Actions", forUser: userName) as? [[String: Any]] else {
            Logger.shared.logError("No administrator-defined Actions found")
            return nil
        }

        guard let action = actions.first(where: { ($0["Name"] as? String) == name }) else {
            Logger.shared.logError("No administrator-defined action named '\(name)'")
            return nil
        }

        let isPrivileged = (action["IsPrivileged"] as? Bool)
            ?? (action["IsPrivileged"] as? NSNumber)?.boolValue
            ?? false

        guard isPrivileged else {
            Logger.shared.logError("Action '\(name)' is not marked IsPrivileged")
            return nil
        }

        guard let command = action["Command"] as? String, !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.shared.logError("Action '\(name)' has no Command")
            return nil
        }

        return command
    }

    /// Where the helper looked for a setting and what it found at each place.
    ///
    /// The app and the helper read preferences by different routes — the app through `CFPreferences`,
    /// which knows about profiles scoped to the logged-in user, and the helper by reading the files,
    /// because as root it is not that user and would never be shown their profile. The two can
    /// therefore disagree, and when they do it is the helper's answer that decides. This says, in one
    /// line, what the helper's answer was built from.
    static func describeSearch(forKey key: String, forUser userName: String?) -> String {
        searchPaths(forUser: userName).map { path in
            guard FileManager.default.fileExists(atPath: path) else {
                return "\(path): absent"
            }

            guard let plist = contents(ofPlistAt: path) else {
                return "\(path): unreadable, or not owned by root"
            }

            guard let value = plist[key] else {
                return "\(path): present, but has no \(key)"
            }

            return "\(path): \(key) = \(value)"
        }
        .joined(separator: " | ")
    }

    // MARK: User installs

    /// Whether a standard user may install allowlisted applications through the helper.
    static func enableUserInstalls(forUser userName: String?) -> Bool {
        bool(forKey: "EnableUserInstalls", default: false, forUser: userName)
    }

    /// Whether the app must authenticate the user before asking for an install.
    ///
    /// The point of the feature is that nobody types an administrator password any more. Replacing that
    /// with nothing at all would make an unlocked, unattended Mac enough, so the default is to ask the
    /// user for their own credentials instead.
    static func requireAuthenticationForInstalls(forUser userName: String?) -> Bool {
        bool(forKey: "RequireAuthenticationForInstalls", default: true, forUser: userName)
    }

    /// What the app should offer when an installer is not on the allowlist.
    ///
    /// `installer` is the default because it is what a double-click does when Support Companion is not
    /// involved at all: the file opens in Installer.app and the administrator password is asked for as
    /// it always was. Nothing the user could do before stops working because this feature exists.
    static func installFallback(forUser userName: String?) -> InstallerAssessment.Fallback {
        let raw = (object(forKey: "UserInstallFallback", forUser: userName) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard let raw, let fallback = InstallerAssessment.Fallback(rawValue: raw) else {
            return .installer
        }

        return fallback
    }

    /// The applications a standard user may install, as an administrator wrote them.
    ///
    /// Entries that cannot decide anything are dropped and logged rather than treated as permissive: a
    /// half-written entry is a mistake, and the safe reading of a mistake is that nothing was allowed.
    static func allowedInstallers(forUser userName: String?) -> [AllowedInstaller] {
        guard let raw = object(forKey: "AllowedInstallers", forUser: userName) as? [[String: Any]] else {
            Logger.shared.logError("No administrator-defined AllowedInstallers found")
            return []
        }

        return raw.compactMap { dictionary in
            let (entry, problem) = AllowedInstaller.make(from: dictionary)

            if let problem {
                Logger.shared.logError("Ignoring an AllowedInstallers entry: \(problem)")
            }

            return entry
        }
    }
}

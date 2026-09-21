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
/// 3. `/Library/Preferences/<domain>.plist` — set by an administrator on the device
enum HelperPreferences {

    private static let domain = "com.github.macadmins.SupportCompanion"

    private static func searchPaths(forUser userName: String?) -> [String] {
        var paths: [String] = []

        if let userName, !userName.isEmpty {
            paths.append("/Library/Managed Preferences/\(userName)/\(domain).plist")
        }

        paths.append("/Library/Managed Preferences/\(domain).plist")
        paths.append("/Library/Preferences/\(domain).plist")

        return paths
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
}

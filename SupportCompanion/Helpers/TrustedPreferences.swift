//
//  TrustedPreferences.swift
//  SupportCompanion
//

import Foundation

/// Reads settings that gate privileged behavior (root actions, admin elevation, allowed installers).
///
/// Any user can write to their own defaults domain with `defaults write`, and `UserDefaults.standard`
/// happily returns those values. For settings that decide what runs as root, only keys forced by an
/// MDM configuration profile are honored. Anything else falls back to the secure default.
///
/// `/Library/Preferences/com.github.macadmins.SupportCompanion.plist` used to count as well, on the
/// grounds that only root can write it. That is true and is the problem: anything that reaches root
/// once — a privileged action, somebody inside an elevation window — could write itself a permanent
/// grant of elevation and of the installer allowlist, and nothing would ever put it back. A profile
/// is owned by the MDM, which re-applies it. See `HelperPreferences`, which makes the same choice on
/// the root side and is the copy that actually decides anything.
enum TrustedPreferences {
    private static let domain = "com.github.macadmins.SupportCompanion" as CFString

    static func object(forKey key: String) -> Any? {
        if UserDefaults.standard.objectIsForced(forKey: key) {
            return UserDefaults.standard.object(forKey: key)
        }

        warnIfPresentUnmanaged(key)

        return nil
    }

    /// Say when a setting is being ignored because of where it lives.
    ///
    /// Silently falling back to a default looks like the feature breaking for no reason to anyone who
    /// configured this with something other than an MDM.
    private static func warnIfPresentUnmanaged(_ key: String) {
        let unmanaged = CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
            ?? CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesAnyUser, kCFPreferencesAnyHost)

        guard unmanaged != nil else { return }

        Logger.shared.logError(
            "Ignoring '\(key)' from /Library/Preferences: settings that grant privileges are only read from a configuration profile. Deliver it through your MDM."
        )
    }

    static func bool(forKey key: String, default defaultValue: Bool) -> Bool {
        let value = object(forKey: key)
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? defaultValue
    }

    static func int(forKey key: String, default defaultValue: Int) -> Int {
        let value = object(forKey: key)
        return (value as? Int) ?? (value as? NSNumber)?.intValue ?? defaultValue
    }

    static func string(forKey key: String, default defaultValue: String) -> String {
        object(forKey: key) as? String ?? defaultValue
    }
}

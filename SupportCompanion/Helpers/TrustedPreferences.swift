//
//  TrustedPreferences.swift
//  SupportCompanion
//

import Foundation

/// Reads settings that gate privileged behavior (root actions, admin elevation).
///
/// Any user can write to their own defaults domain with `defaults write`, and `UserDefaults.standard`
/// happily returns those values. For settings that decide what runs as root, only values set by an
/// administrator are honored:
/// - keys forced by an MDM configuration profile
/// - keys in `/Library/Preferences/com.github.macadmins.SupportCompanion.plist`, which only root can write
///
/// Anything else falls back to the secure default.
enum TrustedPreferences {
    private static let domain = "com.github.macadmins.SupportCompanion" as CFString

    static func object(forKey key: String) -> Any? {
        if UserDefaults.standard.objectIsForced(forKey: key) {
            return UserDefaults.standard.object(forKey: key)
        }
        return CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesAnyUser, kCFPreferencesCurrentHost)
            ?? CFPreferencesCopyValue(key as CFString, domain, kCFPreferencesAnyUser, kCFPreferencesAnyHost)
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

//
//  InstallerServiceMenu.swift
//  SupportCompanion
//

import AppKit
import Foundation

/// Shows or hides the "Install with Support Companion" item in Finder's contextual menu.
///
/// The item itself is declared in `NSServices` in the app's `Info.plist`, which is signed and cannot
/// be edited at runtime — so whether it *appears* is controlled the same way System Settings controls
/// it, through the `pbs` preference domain. Each service has an entry in `NSServicesStatus` holding
/// `enabled_context_menu` and `enabled_services_menu`.
///
/// This is not API. The key naming it is built from the bundle identifier, the menu item's title and
/// the message name, and a service that has never been toggled has no entry at all. Both are handled
/// below, but if Apple changes the format the worst case is that the item stays visible — the feature
/// still refuses to do anything when an administrator has not enabled it, because the helper decides
/// that and not this.
enum InstallerServiceMenu {

    private static let domain = "pbs" as CFString
    private static let statusKey = "NSServicesStatus" as CFString

    /// The `NSMessage` from `Info.plist`, which is the stable part of the key.
    private static let message = "installOpenedInstaller"

    /// `<bundle identifier> - <menu item title> - <message>`, as `pbs` writes it.
    private static var preferredKey: String {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.github.macadmins.SupportCompanion"
        return "\(bundleIdentifier) - Install with Support Companion - \(message)"
    }

    static func apply(showing shouldShow: Bool) {
        var status = (CFPreferencesCopyAppValue(statusKey, domain) as? [String: Any]) ?? [:]

        let setting: [String: Any] = [
            "enabled_context_menu": shouldShow,
            "enabled_services_menu": shouldShow,
        ]

        // Update whatever macOS has already written for this service, whatever it decided to call it,
        // rather than adding a second entry it will ignore.
        let existing = status.keys.filter { $0.contains(message) }

        for key in existing {
            status[key] = setting
        }

        if existing.isEmpty {
            status[preferredKey] = setting
        }

        CFPreferencesSetAppValue(statusKey, status as CFDictionary, domain)
        CFPreferencesAppSynchronize(domain)

        NSUpdateDynamicServices()

        Logger.shared.logDebug(
            "Finder service item \(shouldShow ? "shown" : "hidden") via \(existing.isEmpty ? preferredKey : existing.joined(separator: ", "))"
        )
    }
}

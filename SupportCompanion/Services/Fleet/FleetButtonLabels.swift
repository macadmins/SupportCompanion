//
//  FleetButtonLabels.swift
//  SupportCompanion
//
//  Custom button text for Fleet self-service titles, from the `FleetButtonLabels` preference.
//
//  Keys are a software title's id (as a string), display name, or name; the id wins, then an exact name
//  match, then a case-insensitive one. Values are either a string, which replaces the Install label, or a
//  dictionary with any of `Install`, `Update`, `Reinstall` and `Uninstall`:
//
//      <key>FleetButtonLabels</key>
//      <dict>
//          <key>Request software</key>
//          <string>Request</string>
//          <key>42</key>
//          <dict>
//              <key>Install</key>
//              <string>Get</string>
//              <key>Uninstall</key>
//              <string>Remove</string>
//          </dict>
//      </dict>
//

import Foundation

struct FleetButtonLabels {
    private let entries: [String: Any]

    init(_ entries: [String: Any]?) {
        self.entries = entries ?? [:]
    }

    /// The labels from the `FleetButtonLabels` preference; views reading it update when it changes.
    @MainActor static var current: FleetButtonLabels {
        FleetButtonLabels(DefaultsStore.optionalValue(forKey: "FleetButtonLabels"))
    }

    func label(for title: FleetSoftwareTitle, action: FleetSoftwareTitle.Action) -> String {
        customLabel(for: title, action: action) ?? Self.defaultLabel(for: action)
    }

    static func defaultLabel(for action: FleetSoftwareTitle.Action) -> String {
        switch action {
        case .install: return Constants.Fleet.install
        case .update: return Constants.Fleet.update
        case .reinstall: return Constants.Fleet.reinstall
        case .uninstall: return Constants.Fleet.uninstall
        }
    }

    private func customLabel(for title: FleetSoftwareTitle, action: FleetSoftwareTitle.Action) -> String? {
        guard let entry = entry(for: title) else { return nil }

        if let label = entry as? String {
            return action == .install ? nonEmpty(label) : nil
        }
        guard let labels = entry as? [String: Any] else { return nil }
        let key: String
        switch action {
        case .install: key = "Install"
        case .update: key = "Update"
        case .reinstall: key = "Reinstall"
        case .uninstall: key = "Uninstall"
        }
        return (labels[key] as? String).flatMap(nonEmpty)
    }

    private func entry(for title: FleetSoftwareTitle) -> Any? {
        if let entry = entries[String(title.id)] {
            return entry
        }
        let names = [title.displayName, title.name].compactMap { $0 }.filter { !$0.isEmpty }
        for name in names {
            if let entry = entries[name] {
                return entry
            }
        }
        for name in names {
            if let key = entries.keys.first(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                return entries[key]
            }
        }
        return nil
    }

    private func nonEmpty(_ string: String) -> String? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

//
//  FleetRecommendedApps.swift
//  SupportCompanion
//
//  Apps IT highlights at the top of the Fleet catalog, whether or not they're installed, from the `FleetRecommendedApps` preference: an
//  array of software title ids (as strings), display names or names, in the order to show them.
//  `FleetRecommendedTitle` renames the section.
//
//      <key>FleetRecommendedApps</key>
//      <array>
//          <string>Slack</string>
//          <string>42</string>
//      </array>
//      <key>FleetRecommendedTitle</key>
//      <string>Start here</string>
//

import Foundation

struct FleetRecommendedApps {
    let keys: [String]
    let sectionTitle: String

    init(keys: [String]?, sectionTitle: String? = nil) {
        self.keys = keys ?? []
        let trimmed = sectionTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.sectionTitle = trimmed.isEmpty ? Constants.Fleet.recommended : trimmed
    }

    @MainActor static var current: FleetRecommendedApps {
        FleetRecommendedApps(
            keys: DefaultsStore.optionalValue(forKey: "FleetRecommendedApps"),
            sectionTitle: DefaultsStore.optionalValue(forKey: "FleetRecommendedTitle")
        )
    }

    /// The recommended titles among `titles`, in the preference's order.
    func titles(from titles: [FleetSoftwareTitle]) -> [FleetSoftwareTitle] {
        var seen: Set<Int> = []
        return keys.compactMap { key in
            guard let title = titles.first(where: { $0.matches(key) }), seen.insert(title.id).inserted else { return nil }
            return title
        }
    }
}

//
//  CatalogSuggestion.swift
//  SupportCompanion
//

import Foundation

/// One thing an organisation's software catalog offers, reduced to what matching needs.
///
/// Each mode has its own model — a Fleet title, a Munki optional install, a Jamf policy — and each
/// maps it to this. The matching rule then lives in one place instead of once per mode.
struct CatalogEntry {
    let name: String
    let bundleIdentifier: String?
}

/// A catalog entry that looks like the installer somebody just opened, and where to send them for it.
struct CatalogSuggestion: Equatable {
    /// What the catalog calls it.
    let name: String

    /// Where the approved copy lives, from the mode's own `managementApp(forUpdates:)` — the Apps
    /// page for Fleet, Managed Software Center for Munki, and so on.
    let destinationName: String
    let destinationPath: String
}

/// Decides whether a catalog offers what an installer contains.
///
/// Deliberately strict. Sending somebody to install the wrong application is worse than saying
/// nothing at all, so a near miss is treated as a miss.
enum CatalogMatching {

    static func match(_ facts: InstallerFacts, in entries: [CatalogEntry]) -> CatalogEntry? {
        guard !entries.isEmpty else { return nil }

        // A bundle identifier is the only exact signal, so it decides on its own.
        if let exact = entries.first(where: { entry in
            guard let bundleIdentifier = entry.bundleIdentifier, !bundleIdentifier.isEmpty else { return false }
            return facts.identifiers.contains(bundleIdentifier)
        }) {
            return exact
        }

        // Otherwise the name, with version numbers and punctuation removed from both sides, and only
        // on equality: "Firefox 156.0.dmg" is Firefox, while "Firefox" is not "Firefox Developer".
        let wanted = Set(
            [facts.displayName, (facts.fileName as NSString).deletingPathExtension]
                .compactMap { $0 }
                .map(comparable)
                .filter { !$0.isEmpty }
        )

        guard !wanted.isEmpty else { return nil }

        return entries.first { wanted.contains(comparable($0.name)) }
    }

    /// A name with its version dropped, so "Slack_V4.40.128" and "Slack" are the same thing.
    ///
    /// Version *tokens* go rather than every digit: an installer is as likely to be called
    /// "1Password" as "Firefox 156.0", and throwing away all digits would reduce the first to
    /// "password" and match the wrong thing — or nothing.
    static func comparable(_ name: String) -> String {
        name
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .filter { !isVersion(String($0)) }
            .joined()
            .lowercased()
    }

    /// Whether a token is only a version: "156", "4", "v2" — but not "1Password" or "3T".
    private static func isVersion(_ token: String) -> Bool {
        token.range(of: #"^[vV]?\d+$"#, options: .regularExpression) != nil
    }
}

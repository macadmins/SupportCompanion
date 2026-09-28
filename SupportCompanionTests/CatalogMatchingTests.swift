//
//  CatalogMatchingTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@Suite("Catalog matching")
struct CatalogMatchingTests {

    private let catalog = [
        CatalogEntry(name: "Firefox", bundleIdentifier: "org.mozilla.firefox"),
        CatalogEntry(name: "Google Chrome", bundleIdentifier: "com.google.Chrome"),
        CatalogEntry(name: "Slack", bundleIdentifier: nil),
    ]

    private func facts(
        fileName: String,
        displayName: String? = nil,
        identifiers: [String] = []
    ) -> InstallerFacts {
        InstallerFacts(kind: .diskImage, fileName: fileName, sha256: "", identifiers: identifiers, displayName: displayName)
    }

    @Test("Matches on bundle identifier regardless of what the file is called")
    func byBundleIdentifier() {
        let match = CatalogMatching.match(
            facts(fileName: "fx-installer-final-2.dmg", identifiers: ["org.mozilla.firefox"]),
            in: catalog
        )
        #expect(match?.name == "Firefox")
    }

    @Test("Matches on name once versions and punctuation are removed")
    func byName() {
        #expect(CatalogMatching.match(facts(fileName: "Firefox 156.0.dmg"), in: catalog)?.name == "Firefox")
        #expect(CatalogMatching.match(facts(fileName: "Slack_V4.40.128.dmg"), in: catalog)?.name == "Slack")
        #expect(CatalogMatching.match(facts(fileName: "x.pkg", displayName: "Google Chrome"), in: catalog)?.name == "Google Chrome")
    }

    @Test("Does not match a different application with a similar name")
    func noNearMisses() {
        #expect(CatalogMatching.match(facts(fileName: "Firefox Developer Edition.dmg"), in: catalog) == nil)
        #expect(CatalogMatching.match(facts(fileName: "autopkg-2.9.0.pkg"), in: catalog) == nil)
        #expect(CatalogMatching.match(facts(fileName: "Firefox.dmg"), in: []) == nil)
    }

    @Test("An identifier for something else does not drag in a name match")
    func identifierWins() {
        // The bundle identifier is authoritative, so a file named after one app carrying another's
        // identifier resolves to the identifier.
        let match = CatalogMatching.match(
            facts(fileName: "Firefox 156.0.dmg", identifiers: ["com.google.Chrome"]),
            in: catalog
        )
        #expect(match?.name == "Google Chrome")
    }
}

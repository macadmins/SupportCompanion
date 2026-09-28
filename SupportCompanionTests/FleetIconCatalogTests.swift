//
//  FleetIconCatalogTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@MainActor
@Suite("Fleet icon catalog")
struct FleetIconCatalogTests {
    private let source = """
    import { ISoftware } from "interfaces/software";
    import Slack from "./Slack";
    import Audacity from "./png/Audacity.png";
    import GoogleChrome from "./png/Google-chrome.png";
    import Arc from "./png/Arc.png";
    import Archaeology from "./png/Archaeology.png";

    export const SOFTWARE_NAME_TO_ICON_MAP = {
      audacity: Audacity,
      "google chrome": GoogleChrome,
      slack: Slack,
      arc: Arc,
      "archaeology": Archaeology,
    } as const;

    export const SOFTWARE_SOURCE_TO_ICON_MAP = {
      apps: Audacity,
    };
    """

    @Test("Parses name keys that point at PNG icons only")
    func parse() {
        let files = FleetIconCatalog.parseIndex(source)
        #expect(files == [
            "audacity": "Audacity.png",
            "google chrome": "Google-chrome.png",
            "arc": "Arc.png",
            "archaeology": "Archaeology.png",
        ])
    }

    @Test("Matches like Fleet: whole name or a prefix followed by a space, longest key first")
    func matching() {
        let files = FleetIconCatalog.parseIndex(source)
        #expect(FleetIconCatalog.match("google chrome", in: files) == "Google-chrome.png")
        #expect(FleetIconCatalog.match("audacity 3", in: files) == "Audacity.png")
        #expect(FleetIconCatalog.match("archaeology", in: files) == "Archaeology.png")
        #expect(FleetIconCatalog.match("arcade", in: files) == nil)
        #expect(FleetIconCatalog.match("slack", in: files) == nil)
    }
}

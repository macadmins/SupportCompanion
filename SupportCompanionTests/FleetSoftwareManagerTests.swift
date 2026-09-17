//
//  FleetSoftwareManagerTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

/// Scripted stand-in for FleetClient.
private actor FakeFleetAPI: FleetSoftwareAPI {
    nonisolated let configurationProblem: String?
    var softwareResults: [Result<[FleetSoftwareTitle], FleetError>]
    var categoryResults: [Result<[FleetSoftwareCategory], FleetError>]
    var installError: FleetError?
    private(set) var softwareCalls = 0
    private(set) var categoryCalls = 0
    private(set) var installedIDs: [Int] = []
    private(set) var uninstalledIDs: [Int] = []
    private(set) var refetchCalls = 0

    init(configurationProblem: String? = nil,
         software: [Result<[FleetSoftwareTitle], FleetError>] = [],
         categories: [Result<[FleetSoftwareCategory], FleetError>] = []) {
        self.configurationProblem = configurationProblem
        self.softwareResults = software
        self.categoryResults = categories
    }

    func selfServiceSoftware() async throws -> [FleetSoftwareTitle] {
        softwareCalls += 1
        return try (softwareResults.isEmpty ? .success([]) : softwareResults.removeFirst()).get()
    }

    func selfServiceCategories() async throws -> [FleetSoftwareCategory] {
        categoryCalls += 1
        return try (categoryResults.isEmpty ? .success([]) : categoryResults.removeFirst()).get()
    }

    func install(titleID: Int) async throws {
        if let installError { throw installError }
        installedIDs.append(titleID)
    }

    func uninstall(titleID: Int) async throws {
        uninstalledIDs.append(titleID)
    }

    func installResult(installUUID: String) async throws -> FleetInstallResult? {
        let json = #"{"install_uuid": "\#(installUUID)", "output": "Installer failed", "post_install_script_output": "exit 1"}"#
        return try JSONDecoder.fleet.decode(FleetInstallResult.self, from: Data(json.utf8))
    }

    func uninstallResult(executionID: String) async throws -> FleetScriptResult {
        try JSONDecoder.fleet.decode(FleetScriptResult.self, from: Data(#"{"output": "removed"}"#.utf8))
    }

    func refetch() async throws {
        refetchCalls += 1
    }

    func setInstallError(_ error: FleetError?) {
        installError = error
    }
}

private func title(_ id: Int, _ name: String, installed: String? = nil, available: String? = "1.0", status: String? = nil, displayName: String = "") -> FleetSoftwareTitle {
    var json: [String: Any] = ["id": id, "name": name, "display_name": displayName]
    if let status { json["status"] = status }
    if let installed { json["installed_versions"] = [["version": installed]] }
    if let available { json["software_package"] = ["version": available, "self_service": true] }
    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder.fleet.decode(FleetSoftwareTitle.self, from: data)
}

@MainActor
@Suite("Fleet software manager")
struct FleetSoftwareManagerTests {

    @Test("Loads and sorts titles by name")
    func loadsAndSorts() async {
        let api = FakeFleetAPI(software: [.success([title(2, "zoom"), title(1, "Arc"), title(3, "Slack")])])
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()

        #expect(manager.loadState == .loaded)
        #expect(manager.titles.map(\.title) == ["Arc", "Slack", "zoom"])
        #expect(manager.lastUpdated != nil)
    }

    @Test("Not configured when orbit or the server URL is missing, without calling Fleet")
    func notConfigured() async {
        let api = FakeFleetAPI(configurationProblem: "No Fleet server URL found")
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()

        #expect(manager.loadState == .notConfigured)
        #expect(manager.configurationProblem == "No Fleet server URL found")
        #expect(await api.softwareCalls == 0)
    }

    @Test("SSO required is surfaced as its own state")
    func ssoRequired() async {
        let manager = FleetSoftwareManager(client: FakeFleetAPI(software: [.failure(.ssoRequired)]))

        await manager.refresh()

        #expect(manager.loadState == .ssoRequired)
    }

    @Test("A failed refresh keeps the previous catalog")
    func failedRefreshKeepsTitles() async {
        let api = FakeFleetAPI(software: [.success([title(1, "Arc")]), .failure(.server(status: 500, message: "boom"))])
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()
        await manager.refresh()

        #expect(manager.titles.map(\.title) == ["Arc"])
        guard case .failed(let message) = manager.loadState else {
            Issue.record("Expected a failed state, got \(manager.loadState)")
            return
        }
        #expect(message == "boom")
    }

    @Test("Stops requesting categories after the server reports it doesn't have them")
    func categoriesUnsupported() async {
        let api = FakeFleetAPI(
            software: [.success([title(1, "Arc")]), .success([title(1, "Arc")])],
            categories: [.failure(.server(status: 404, message: "")), .success([])]
        )
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()
        await manager.refresh()

        #expect(await api.categoryCalls == 1)
        #expect(manager.loadState == .loaded)
    }

    @Test("Updates available lists only titles with a newer version")
    func updatesAvailable() async {
        let api = FakeFleetAPI(software: [.success([
            title(1, "Arc", installed: "1.0", available: "1.1"),
            title(2, "Slack", installed: "4.42", available: "4.42"),
            title(3, "Zoom", installed: nil, available: "6.0"),
        ])])
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()

        #expect(manager.updatesAvailable.map(\.title) == ["Arc"])
    }

    @Test("An install is followed until Fleet reports it finished")
    func installLifecycle() async {
        let api = FakeFleetAPI(software: [
            .success([title(1, "Arc", installed: nil, available: "1.0")]),
            .success([title(1, "Arc", installed: nil, available: "1.0", status: "pending_install")]),
            .success([title(1, "Arc", installed: "1.0", available: "1.0", status: "installed")]),
        ])
        let manager = FleetSoftwareManager(client: api, pendingPollInterval: 60)
        var finished: [(Int, FleetSoftwareTitle.Action, Bool)] = []
        manager.onActionFinished = { finished.append(($0.id, $1, $2)) }

        await manager.refresh()
        await manager.perform(.install, on: manager.titles[0])

        #expect(await api.installedIDs == [1])
        #expect(manager.isBusy(manager.titles[0]))

        await manager.refresh()

        #expect(manager.runningActions.isEmpty)
        #expect(finished.count == 1)
        #expect(finished.first?.1 == .install)
        #expect(finished.first?.2 == true)
    }

    @Test("A title's status from before the action isn't taken as its result")
    func waitsForPending() async {
        let api = FakeFleetAPI(software: [
            .success([title(1, "Arc", installed: "1.0", available: "1.1")]),
            .success([title(1, "Arc", installed: "1.0", available: "1.1")]),
        ])
        let manager = FleetSoftwareManager(client: api, pendingPollInterval: 60)
        var finishedCount = 0
        manager.onActionFinished = { _, _, _ in finishedCount += 1 }

        await manager.refresh()
        await manager.perform(.update, on: manager.titles[0])

        #expect(manager.runningActions[1] == .update)
        #expect(finishedCount == 0)
    }

    @Test("A failed install request is shown on the title and nothing is left running")
    func installRequestFails() async {
        let api = FakeFleetAPI(software: [.success([title(1, "Arc")])])
        await api.setInstallError(.server(status: 422, message: "Software is not available"))
        let manager = FleetSoftwareManager(client: api)

        await manager.refresh()
        await manager.perform(.install, on: manager.titles[0])

        #expect(manager.runningActions.isEmpty)
        #expect(manager.actionErrors[1] == "Software is not available")
    }

    @Test("Failure output combines the install result's outputs")
    func failureOutput() async throws {
        let json = #"{"id": 1, "name": "Arc", "status": "failed_install", "software_package": {"version": "1.0", "last_install": {"install_uuid": "abc-123"}}}"#
        let failed = try JSONDecoder.fleet.decode(FleetSoftwareTitle.self, from: Data(json.utf8))
        let manager = FleetSoftwareManager(client: FakeFleetAPI())

        let output = try await manager.failureOutput(for: failed)

        #expect(output == "Installer failed\n\nexit 1")
    }
}

@Suite("Fleet button labels")
struct FleetButtonLabelsTests {
    @Test("Defaults when nothing is configured")
    func defaults() {
        let labels = FleetButtonLabels(nil)
        #expect(labels.label(for: title(1, "Arc"), action: .install) == "Install")
        #expect(labels.label(for: title(1, "Arc"), action: .uninstall) == "Uninstall")
    }

    @Test("A string replaces only the install label")
    func stringValue() {
        let labels = FleetButtonLabels(["Request software": "Request"])
        let requested = title(7, "request_software", displayName: "Request software")
        #expect(labels.label(for: requested, action: .install) == "Request")
        #expect(labels.label(for: requested, action: .update) == "Update")
    }

    @Test("A dictionary sets each action, and the title id wins over the name")
    func dictionaryAndIdPriority() {
        let labels = FleetButtonLabels([
            "Arc": ["Install": "By name"],
            "1": ["Install": "Get", "Uninstall": "Remove", "Update": " "],
        ])
        #expect(labels.label(for: title(1, "Arc"), action: .install) == "Get")
        #expect(labels.label(for: title(1, "Arc"), action: .uninstall) == "Remove")
        #expect(labels.label(for: title(1, "Arc"), action: .update) == "Update")
    }

    @Test("Names match case-insensitively")
    func caseInsensitive() {
        let labels = FleetButtonLabels(["slack": "Request"])
        #expect(labels.label(for: title(2, "Slack"), action: .install) == "Request")
    }

    @Test("An update stays available while installing and until inventory shows the new version")
    @MainActor func updateStaysUntilInventory() async {
        let api = FakeFleetAPI(software: [
            .success([title(1, "Arc", installed: "1.0", available: "1.1")]),
            .success([title(1, "Arc", installed: "1.0", available: "1.1", status: "pending_install")]),
            .success([title(1, "Arc", installed: "1.0", available: "1.1", status: "installed")]),
            .success([title(1, "Arc", installed: "1.1", available: "1.1", status: "installed")]),
        ])
        let manager = FleetSoftwareManager(client: api, pendingPollInterval: 60)

        await manager.refresh()
        await manager.perform(.update, on: manager.titles[0])
        #expect(manager.updatesAvailable.map(\.id) == [1]) // pending: still listed as an update

        await manager.refresh()
        #expect(manager.updatesAvailable.isEmpty) // Fleet says installed, inventory still shows 1.0
        #expect(manager.installedVersionsAwaitingInventory[1] == "1.1")

        await manager.refresh()
        #expect(manager.updatesAvailable.isEmpty)
        #expect(manager.installedVersionsAwaitingInventory.isEmpty) // inventory caught up
    }

    @Test("Reinstall is offered for up-to-date titles only, and can be relabeled")
    func reinstall() {
        let upToDate = title(1, "Arc", installed: "1.0", available: "1.0", status: "installed")
        let outdated = title(2, "Slack", installed: "4.0", available: "4.1")
        #expect(upToDate.canReinstall)
        #expect(!outdated.canReinstall)
        #expect(FleetButtonLabels(["Arc": ["Reinstall": "Repair"]]).label(for: upToDate, action: .reinstall) == "Repair")
    }
}

@Suite("Fleet pending updates")
struct PendingFleetUpdateTests {
    @Test("Only titles with a newer version become pending updates, with stable ids")
    func pendingUpdates() {
        let outdated = title(42, "Slack", installed: "4.0", available: "4.1")
        let update = PendingFleetUpdate(title: outdated)
        #expect(update?.version == "4.0 → 4.1")
        #expect(update?.id == PendingFleetUpdate(title: outdated)?.id)
        #expect(PendingFleetUpdate(title: title(1, "Arc", installed: "1.0", available: "1.0")) == nil)
        #expect(PendingFleetUpdate(title: title(3, "Zoom", installed: nil, available: "6.0")) == nil)
    }
}

@Suite("Fleet recommended apps")
struct FleetRecommendedAppsTests {
    @Test("Recommended titles follow the preference order and match ids or names")
    func order() {
        let titles = [title(1, "Arc"), title(2, "Slack"), title(3, "zoom.us", displayName: "Zoom")]
        let recommended = FleetRecommendedApps(keys: ["zoom", "1", "Missing", "arc"], sectionTitle: " ")
        #expect(recommended.titles(from: titles).map(\.id) == [3, 1])
        #expect(recommended.sectionTitle == "Recommended")
        #expect(FleetRecommendedApps(keys: nil, sectionTitle: "Start here").sectionTitle == "Start here")
    }
}

//
//  FleetDeviceManagerTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

private actor FakePolicyAPI: FleetDeviceAPI {
    nonisolated let configurationProblem: String? = nil
    private var results: [Result<[FleetPolicy], FleetError>]
    private var refetchRequested: [Bool]
    private(set) var refetchCalls = 0
    /// What the ungated `/desktop` endpoint answers, or nil to make it fail like the gated calls.
    var summaryFailingCount: Int?

    init(_ results: [Result<[FleetPolicy], FleetError>], refetchRequested: [Bool] = []) {
        self.results = results
        self.refetchRequested = refetchRequested
    }

    func deviceHost() async throws -> FleetHost {
        let policies = try (results.isEmpty ? .success([]) : results.removeFirst()).get()
        let requested = refetchRequested.isEmpty ? false : refetchRequested.removeFirst()
        return try host(policies: policies, refetchRequested: requested)
    }

    func desktopSummary() async throws -> FleetDesktopSummary {
        guard let summaryFailingCount else { throw FleetError.network("no summary") }
        let json: [String: Any] = ["failing_policies_count": summaryFailingCount, "self_service": true]
        return try JSONDecoder.fleet.decode(FleetDesktopSummary.self, from: JSONSerialization.data(withJSONObject: json))
    }

    func setSummaryFailingCount(_ count: Int?) {
        summaryFailingCount = count
    }

    func refetch() async throws {
        refetchCalls += 1
    }

    private func host(policies: [FleetPolicy], refetchRequested: Bool) throws -> FleetHost {
        let policyJSON = policies.map { ["id": $0.id, "name": $0.name, "response": $0.response ?? "", "critical": $0.critical ?? false] as [String: Any] }
        let json: [String: Any] = ["id": 7, "refetch_requested": refetchRequested, "policies": policyJSON]
        return try JSONDecoder.fleet.decode(FleetHost.self, from: JSONSerialization.data(withJSONObject: json))
    }
}

private func policy(_ id: Int, _ name: String, _ response: String, critical: Bool = false) -> FleetPolicy {
    let json: [String: Any] = ["id": id, "name": name, "response": response, "critical": critical]
    return try! JSONDecoder.fleet.decode(FleetPolicy.self, from: JSONSerialization.data(withJSONObject: json))
}

@MainActor
@Suite("Fleet device manager")
struct FleetDeviceManagerTests {
    private func makeDefaults() -> UserDefaults {
        let name = "FleetDeviceManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("A failing policy is reported once, and again only after it passed")
    func reportsOncePerFailure() async {
        let fileVault = policy(1, "FileVault enabled", "fail")
        let api = FakePolicyAPI([
            .success([fileVault, policy(2, "Firewall", "pass")]),
            .success([fileVault, policy(2, "Firewall", "pass")]),
            .success([policy(1, "FileVault enabled", "pass")]),
            .success([fileVault]),
        ])
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())
        var reported: [[Int]] = []
        manager.onNewlyFailing = { reported.append($0.map(\.id)) }

        for _ in 0..<4 { await manager.refresh() }

        #expect(reported == [[1], [1]])
    }

    @Test("Reported failures survive a relaunch")
    func persisted() async {
        let defaults = makeDefaults()
        let first = FleetDeviceManager(client: FakePolicyAPI([.success([policy(1, "FileVault", "fail")])]), defaults: defaults)
        await first.refresh()

        let relaunched = FleetDeviceManager(client: FakePolicyAPI([.success([policy(1, "FileVault", "fail")])]), defaults: defaults)
        var reported = 0
        relaunched.onNewlyFailing = { _ in reported += 1 }
        await relaunched.refresh()

        #expect(reported == 0)
    }

    @Test("Critical failures come first; policies that haven't run aren't counted")
    func ordering() async {
        let api = FakePolicyAPI([.success([
            policy(1, "A", "fail"), policy(2, "B", "fail", critical: true), policy(3, "C", ""), policy(4, "D", "pass"),
        ])])
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())

        await manager.refresh()

        #expect(manager.failingPolicies.map(\.id) == [2, 1])
        #expect(manager.checkedPolicies.count == 3)
    }

    @Test("Signed out, the failing count comes from the ungated summary")
    func failingCountSurvivesSignedOut() async {
        let api = FakePolicyAPI([.failure(.ssoRequired)])
        await api.setSummaryFailingCount(3)
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())

        await manager.refresh()

        #expect(manager.isSignedOut)
        #expect(manager.policies.isEmpty)
        // The whole point: the badge and the compliance card still say something true
        #expect(manager.failingChecksCount == 3)
    }

    @Test("Signed in, the count comes from the policies, not the summary")
    func signedInPrefersPolicies() async {
        let api = FakePolicyAPI([.success([policy(1, "A", "fail"), policy(2, "B", "pass")])])
        await api.setSummaryFailingCount(99)
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())

        await manager.refresh()

        #expect(!manager.isSignedOut)
        #expect(manager.failingChecksCount == 1)
    }

    /// The summary is a separate request and can fail on its own; that must not invent a count of zero.
    @Test("With no summary and no host, the count is unknown rather than zero")
    func noSummaryMeansUnknown() async {
        let api = FakePolicyAPI([.failure(.ssoRequired)])
        await api.setSummaryFailingCount(nil)
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())

        await manager.refresh()

        #expect(manager.isSignedOut)
        #expect(manager.failingChecksCount == nil)
    }

    @Test("A sign-in is reported once, not on every poll")
    func signInReportedOncePerDay() async {
        let api = FakePolicyAPI([.failure(.ssoRequired), .failure(.ssoRequired), .failure(.ssoRequired)])
        await api.setSummaryFailingCount(0)
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())
        var reports = 0
        manager.onSignInRequired = { reports += 1 }

        await manager.refresh()
        await manager.refresh()
        await manager.refresh()

        // The session stays expired until the user acts, so every poll would otherwise nag
        #expect(reports == 1)
    }

    /// Signing in clears the reminder, so the next sign-out is reported promptly rather than being
    /// swallowed by the remainder of the day's interval.
    @Test("Signing in resets the reminder")
    func signingInResetsReminder() async {
        let api = FakePolicyAPI([
            .failure(.ssoRequired),
            .success([policy(1, "A", "pass")]),
            .failure(.ssoRequired),
        ])
        await api.setSummaryFailingCount(0)
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())
        var reports = 0
        manager.onSignInRequired = { reports += 1 }

        await manager.refresh()
        await manager.refresh()
        await manager.refresh()

        #expect(reports == 2)
    }

    @Test("SSO required keeps earlier policies")
    func ssoRequired() async {
        let api = FakePolicyAPI([.success([policy(1, "A", "fail")]), .failure(.ssoRequired)])
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults())

        await manager.refresh()
        await manager.refresh()

        #expect(manager.loadState == .ssoRequired)
        #expect(manager.policies.count == 1)
    }

    @Test("A second re-check while one is in flight doesn't send another request")
    func refetchOnce() async throws {
        let api = FakePolicyAPI([.success([]), .success([])], refetchRequested: [false, false])
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults(), refetchPollInterval: 60)

        async let first: Void = manager.refetch()
        async let second: Void = manager.refetch()
        _ = try await (first, second)

        #expect(await api.refetchCalls == 1)
    }

    @Test("Refetch waits until Fleet has the new details, then reports it finished")
    func refetch() async throws {
        let api = FakePolicyAPI([.success([]), .success([]), .success([])], refetchRequested: [false, true, false])
        let manager = FleetDeviceManager(client: api, defaults: makeDefaults(), refetchPollInterval: 0.01)
        await manager.refresh()
        var finished = false
        manager.onRefetchFinished = { finished = true }

        try await manager.refetch()
        #expect(manager.isRefetching)
        #expect(await api.refetchCalls == 1)

        for _ in 0..<200 where manager.isRefetching {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!manager.isRefetching)
        #expect(finished)
    }
}

@Suite("Fleet host decoding")
struct FleetHostDecodingTests {
    @Test("Decodes host details with Go zero times, nanoseconds and fleet_name")
    func decode() throws {
        let json = """
        {"host": {"id": 42, "hostname": "mac.local", "seen_time": "2026-09-17T10:11:12.123456789Z",
          "detail_updated_at": "0001-01-01T00:00:00Z", "team_name": null, "fleet_name": "Staff",
          "refetch_requested": false, "policies": [{"id": 1, "name": "FileVault", "response": "fail"}]}}
        """
        let host = try JSONDecoder.fleet.decode(FleetDeviceHostResponse.self, from: Data(json.utf8)).host
        #expect(host.id == 42)
        #expect(host.team == "Staff")
        #expect(FleetHost.realDate(host.seenTime) != nil)
        #expect(FleetHost.realDate(host.detailUpdatedAt) == nil)
        #expect(host.policies?.first?.isFailing == true)
    }
}

//
//  FleetDeviceManager.swift
//  SupportCompanion
//
//  This Mac's Fleet host details and policies, for the Fleet and Device Compliance cards, failing policy
//  notifications and the Refetch action. Both cards come from one request to `GET /device/{token}`.
//

import Foundation
import Observation

@MainActor
@Observable
final class FleetDeviceManager {
    enum LoadState: Equatable {
        case idle
        case loaded
        /// Fleet Desktop SSO is enabled and the user hasn't signed in.
        case ssoRequired
        case failed(String)
    }

    private(set) var host: FleetHost?
    private(set) var loadState: LoadState = .idle
    private(set) var lastUpdated: Date?
    /// A refetch was requested and Fleet hasn't received the Mac's fresh details yet.
    private(set) var isRefetching = false
    /// Why the last re-check couldn't be requested.
    private(set) var refetchError: String?

    var policies: [FleetPolicy] { host?.policies ?? [] }

    /// Rows for the Fleet card.
    var infoRows: [(key: String, display: String, value: InfoValue)] {
        typealias Info = Constants.FleetInfo
        let unknown = Info.unknown
        func relative(_ date: Date?) -> String {
            guard host != nil else { return unknown }
            return FleetHost.realDate(date).map { $0.formatted(.relative(presentation: .named)) } ?? Info.never
        }
        return [
            (Info.Keys.id, Info.Labels.id, .string(host.map { String($0.id) } ?? unknown)),
            (Info.Keys.team, Info.Labels.team, .string(host.map { $0.team ?? Info.noTeam } ?? unknown)),
            (Info.Keys.lastSeen, Info.Labels.lastSeen, .string(relative(host?.seenTime))),
            (Info.Keys.lastInventory, Info.Labels.lastInventory,
             .string(isRefetching ? Constants.Actions.refetching : relative(host?.detailUpdatedAt))),
            (Info.Keys.url, Info.Labels.url, .string(FleetDeviceIdentity.serverURL()?.host() ?? unknown)),
        ]
    }

    /// Called with policies that started failing since the last check, to notify the user once per failure.
    @ObservationIgnored var onNewlyFailing: (([FleetPolicy]) -> Void)?
    /// Called when a refetch finishes, so other Fleet data can be refreshed too.
    @ObservationIgnored var onRefetchFinished: (() -> Void)?

    @ObservationIgnored private let client: any FleetDeviceAPI
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let refetchPollInterval: TimeInterval
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?

    /// Ids of failing policies the user has been told about.
    static let reportedFailuresKey = "FleetReportedFailingPolicies"
    /// Fleet re-runs details and policies at the Mac's next check-in, usually within a minute or two.
    private static let refetchTimeout: TimeInterval = 5 * 60

    init(client: any FleetDeviceAPI = FleetClient.shared, defaults: UserDefaults = .standard, refetchPollInterval: TimeInterval = 15) {
        self.client = client
        self.defaults = defaults
        self.refetchPollInterval = refetchPollInterval
    }

    /// Failing policies, critical ones first.
    var failingPolicies: [FleetPolicy] {
        policies.filter(\.isFailing).sorted {
            if ($0.critical ?? false) != ($1.critical ?? false) { return $0.critical ?? false }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var passingPolicies: [FleetPolicy] {
        policies.filter { $0.response == "pass" }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Policies that have run on this Mac.
    var checkedPolicies: [FleetPolicy] {
        policies.filter { $0.response == "pass" || $0.response == "fail" }
    }

    func refresh() async {
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { await performRefresh() }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func refreshIfStale(maxAge: TimeInterval = 5 * 60) async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < maxAge, loadState == .loaded {
            return
        }
        await refresh()
    }

    /// Checks periodically, for notifications while the app runs in the background.
    func startMonitoring(interval: TimeInterval = 3600) {
        stopMonitoring()
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(interval))
            }
        }
    }

    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Asks Fleet to re-read this Mac's details and re-run its policies, then waits for the results.
    /// Throws if Fleet didn't accept the request; the wait continues in the background.
    func refetch() async throws {
        guard !isRefetching else { return }
        // Set before the request, so a second tap while it's in flight doesn't start another re-check
        isRefetching = true
        refetchError = nil
        do {
            try await client.refetch()
        } catch {
            Logger.shared.logError("Fleet: re-check request failed: \(error.localizedDescription)")
            refetchError = Constants.FleetInfo.refetchFailed
            isRefetching = false
            throw error
        }
        Task { await waitForRefetch() }
    }

    private func waitForRefetch() async {
        let deadline = Date().addingTimeInterval(Self.refetchTimeout)
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(refetchPollInterval))
            await refresh()
            // Stop on errors rather than keep sending requests Fleet refuses
            guard loadState == .loaded else { break }
            if host?.refetchRequested != true { break }
        }
        isRefetching = false
        onRefetchFinished?()
    }

    private func performRefresh() async {
        if let problem = client.configurationProblem {
            loadState = .failed(problem)
            return
        }
        do {
            host = try await client.deviceHost()
            lastUpdated = Date()
            loadState = .loaded
            reportNewlyFailing()
        } catch FleetError.ssoRequired {
            loadState = .ssoRequired
        } catch {
            // Keep showing the last details
            loadState = .failed(error.localizedDescription)
        }
    }

    private func reportNewlyFailing() {
        let reported = Set(defaults.array(forKey: Self.reportedFailuresKey) as? [Int] ?? [])
        let failing = failingPolicies
        let newlyFailing = failing.filter { !reported.contains($0.id) }

        // Forget policies once they pass, so they're reported again if they fail later. Policies that
        // haven't run again yet keep their state.
        let passing = Set(policies.filter { $0.response == "pass" }.map(\.id))
        let knownIDs = Set(policies.map(\.id))
        let stillReported = reported.filter { knownIDs.contains($0) && !passing.contains($0) }
            .union(failing.map(\.id))
        if stillReported != reported {
            defaults.set(stillReported.sorted(), forKey: Self.reportedFailuresKey)
        }

        if !newlyFailing.isEmpty {
            Logger.shared.logDebug("Fleet: \(newlyFailing.count) policies started failing")
            onNewlyFailing?(newlyFailing)
        }
    }
}

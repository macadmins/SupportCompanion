//
//  FleetSoftwareManager.swift
//  SupportCompanion
//
//  Self-service software catalog for Fleet mode.
//

import Foundation
import Observation

@MainActor
@Observable
final class FleetSoftwareManager {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        /// Fleet Desktop SSO is enabled and the user hasn't signed in.
        case ssoRequired
        /// No Fleet server or device token on this Mac.
        case notConfigured
        case failed(String)
    }

    private(set) var titles: [FleetSoftwareTitle] = []
    private(set) var categories: [FleetSoftwareCategory] = []
    private(set) var loadState: LoadState = .idle
    private(set) var lastUpdated: Date?
    /// Why Fleet isn't set up, shown with the `.notConfigured` state.
    private(set) var configurationProblem: String?
    /// Actions started from this app that haven't finished yet, by title id.
    private(set) var runningActions: [Int: FleetSoftwareTitle.Action] = [:]
    /// Why the last action for a title couldn't be started, by title id.
    private(set) var actionErrors: [Int: String] = [:]
    /// Versions Fleet reported installed before its inventory shows them, by title id. Fleet's installed
    /// versions come from inventory, which lags the install result by a minute or more.
    private(set) var installedVersionsAwaitingInventory: [Int: String] = [:]
    /// Failed custom package installs whose output said the app has to be closed, by install UUID.
    private(set) var appOpenInstallUUIDs: Set<String> = []

    enum ActionOutcome: Equatable {
        case succeeded
        case failed
        /// The install didn't run because the app was open.
        case appOpen
    }

    /// Called when an action started from this app finishes.
    @ObservationIgnored var onActionFinished: ((FleetSoftwareTitle, FleetSoftwareTitle.Action, ActionOutcome) -> Void)?
    /// Called after the catalog is fetched.
    @ObservationIgnored var onCatalogUpdated: (() -> Void)?

    @ObservationIgnored private let client: any FleetSoftwareAPI
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private var monitorTask: Task<Void, Never>?
    @ObservationIgnored private var categoriesFetchedAt: Date?
    @ObservationIgnored private var categoriesUnsupported = false
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var actionStartedAt: [Int: Date] = [:]
    /// Running actions Fleet has reported as pending, so a title's status from before the action isn't taken as its result.
    @ObservationIgnored private var actionsSeenPending: Set<Int> = []
    @ObservationIgnored private var polledPendingIDs: Set<Int> = []
    /// Install UUIDs whose output has been checked, so each result is fetched once.
    @ObservationIgnored private var checkedInstallUUIDs: Set<String> = []

    /// Categories rarely change, so they're fetched at most this often.
    private static let categoriesRefreshInterval: TimeInterval = 10 * 60
    private let pendingPollInterval: TimeInterval
    /// Longest time to poll for pending installs; Fleet keeps them pending until the Mac checks in.
    private static let pendingPollLimit: TimeInterval = 30 * 60
    /// How long an action may go without Fleet reporting it pending before its current status is taken as the result.
    private static let pendingGracePeriod: TimeInterval = 2 * 60

    init(client: any FleetSoftwareAPI = FleetClient.shared, pendingPollInterval: TimeInterval = 10) {
        self.client = client
        self.pendingPollInterval = pendingPollInterval
    }

    var updatesAvailable: [FleetSoftwareTitle] {
        titles.filter(hasUpdate)
    }

    /// Whether a newer version is available and hasn't just been installed.
    func hasUpdate(_ title: FleetSoftwareTitle) -> Bool {
        title.isUpdateAvailable && installedVersionsAwaitingInventory[title.id] != title.availableVersion
    }

    /// Whether an install or uninstall is queued or running for the title.
    func isBusy(_ title: FleetSoftwareTitle) -> Bool {
        runningActions[title.id] != nil || title.isPending
    }

    // MARK: - Actions

    /// Asks Fleet to install, update or uninstall a title, then follows it until Fleet reports the result.
    func perform(_ action: FleetSoftwareTitle.Action, on title: FleetSoftwareTitle) async {
        guard !isBusy(title) else { return }
        runningActions[title.id] = action
        actionStartedAt[title.id] = Date()
        actionErrors[title.id] = nil

        do {
            switch action {
            case .install, .update, .reinstall:
                try await client.install(titleID: title.id)
            case .uninstall:
                try await client.uninstall(titleID: title.id)
            }
            Logger.shared.logDebug("Fleet: requested \(action) of \(title.title)")
        } catch {
            Logger.shared.logError("Fleet: couldn't request \(action) of \(title.title): \(error.localizedDescription)")
            clearAction(title.id)
            actionErrors[title.id] = error.localizedDescription
            if case FleetError.ssoRequired = error {
                loadState = .ssoRequired
            }
            return
        }

        await refresh()
        startPollingWhilePending()
    }

    /// Whether the title's last install didn't run because its app was open.
    func isWaitingForAppToClose(_ title: FleetSoftwareTitle) -> Bool {
        guard title.status == .failedInstall else { return false }
        if title.skippedInstall == true { return true }
        return title.installer?.lastInstall?.installUuid.map(appOpenInstallUUIDs.contains) ?? false
    }

    /// The action that retries an install that failed or waited for the app to close.
    func retryAction(for title: FleetSoftwareTitle) -> FleetSoftwareTitle.Action {
        if !title.isInstalled { return .install }
        return hasUpdate(title) ? .update : .reinstall
    }

    /// Quits the title's app and retries its install. Leaves an error on the title if the app didn't quit.
    func quitAndRetry(_ title: FleetSoftwareTitle) async {
        guard await FleetRunningApps.shared.quit(title) else {
            actionErrors[title.id] = String(format: Constants.Fleet.couldNotQuit, title.title)
            return
        }
        await perform(retryAction(for: title), on: title)
    }

    func quitAndRetry(titleID: Int) async {
        await refreshIfStale()
        guard let title = titles.first(where: { $0.id == titleID }) else { return }
        await quitAndRetry(title)
    }

    /// Updates every title with an update available, e.g. from an update notification's button.
    func updateAll() async {
        await refreshIfStale()
        for title in updatesAvailable where !isBusy(title) {
            await perform(.update, on: title)
        }
    }

    /// The output of a title's last failed install or uninstall.
    func failureOutput(for title: FleetSoftwareTitle) async throws -> String {
        if title.status == .failedUninstall {
            guard let executionID = title.softwarePackage?.lastUninstall?.scriptExecutionId else { return "" }
            let result = try await client.uninstallResult(executionID: executionID)
            return Self.joinOutput([result.output, result.message])
        }
        guard let installUUID = title.installer?.lastInstall?.installUuid,
              let result = try await client.installResult(installUUID: installUUID) else { return "" }
        return Self.joinOutput([result.preInstallQueryOutput, result.output, result.postInstallScriptOutput])
    }

    private static func joinOutput(_ parts: [String?]) -> String {
        parts.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    private func clearAction(_ id: Int) {
        runningActions[id] = nil
        actionStartedAt[id] = nil
        actionsSeenPending.remove(id)
    }

    /// Refreshes often while anything is pending, so progress shows without waiting for the regular refresh.
    private func startPollingWhilePending() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self, pendingPollInterval] in
            let deadline = Date().addingTimeInterval(Self.pendingPollLimit)
            while !Task.isCancelled, Date() < deadline {
                try? await Task.sleep(for: .seconds(pendingPollInterval))
                guard let self else { return }
                await self.refresh()
                if !self.titles.contains(where: \.isPending) && self.runningActions.isEmpty {
                    break
                }
                // Don't keep polling a server that's refusing requests
                if self.loadState != .loaded {
                    break
                }
            }
            self?.pollTask = nil
        }
    }

    /// Checks failed custom package installs for output saying the app has to be closed first.
    /// Fleet flags this itself for Fleet-maintained apps, so those aren't fetched.
    private func detectAppOpenInstalls() async {
        let messages = FleetAppOpenMessages.current
        for title in titles where title.status == .failedInstall && title.skippedInstall != true {
            guard let uuid = title.installer?.lastInstall?.installUuid, !checkedInstallUUIDs.contains(uuid) else { continue }
            let fetched: FleetInstallResult?
            do {
                fetched = try await client.installResult(installUUID: uuid)
            } catch FleetError.server(status: 404, _), FleetError.decoding(_) {
                // The result no longer exists or can't be read, so asking again won't help
                checkedInstallUUIDs.insert(uuid)
                continue
            } catch {
                // Network, server or sign-in problems: stop here and check again on the next refresh
                return
            }
            checkedInstallUUIDs.insert(uuid)
            guard let result = fetched else { continue }
            let output = [result.preInstallQueryOutput, result.output, result.postInstallScriptOutput]
                .compactMap { $0 }.joined(separator: "\n")
            if messages.matches(output) {
                appOpenInstallUUIDs.insert(uuid)
            }
        }
    }

    /// Whether the title's failed install output hasn't been checked for an open app yet.
    private func needsOutputCheck(_ title: FleetSoftwareTitle) -> Bool {
        guard title.status == .failedInstall, title.skippedInstall != true,
              let uuid = title.installer?.lastInstall?.installUuid else { return false }
        return !checkedInstallUUIDs.contains(uuid)
    }

    /// Reports actions started from this app that Fleet has finished.
    private func trackRunningActions() {
        for (id, action) in runningActions {
            guard let title = titles.first(where: { $0.id == id }) else {
                clearAction(id)
                continue
            }
            if title.isPending {
                actionsSeenPending.insert(id)
                continue
            }
            let startedAt = actionStartedAt[id] ?? .distantPast
            guard actionsSeenPending.contains(id) || Date().timeIntervalSince(startedAt) > Self.pendingGracePeriod else {
                continue
            }
            // Wait for the install output to be checked, so an install blocked by an open app isn't reported as a
            // plain failure; give up after the polling limit
            if needsOutputCheck(title), Date().timeIntervalSince(startedAt) < Self.pendingPollLimit {
                continue
            }
            clearAction(id)
            let succeeded = !title.hasFailed
            let outcome: ActionOutcome = succeeded ? .succeeded : (isWaitingForAppToClose(title) ? .appOpen : .failed)
            Logger.shared.logDebug("Fleet: \(action) of \(title.title) finished: \(outcome)")
            if succeeded && action != .uninstall, let version = title.availableVersion {
                installedVersionsAwaitingInventory[id] = version
            }
            onActionFinished?(title, action, outcome)
            if succeeded && action != .uninstall {
                // Installed versions come from inventory, which Fleet otherwise updates about hourly
                Task { try? await client.refetch() }
            }
        }
    }

    /// Refreshes the catalog. Concurrent calls share one request.
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

    /// Refreshes unless the catalog was fetched within `maxAge`, so several views asking for data share requests.
    func refreshIfStale(maxAge: TimeInterval = 30) async {
        if let lastUpdated, Date().timeIntervalSince(lastUpdated) < maxAge, loadState == .loaded {
            return
        }
        await refresh()
    }

    /// Refreshes periodically while the catalog is on screen. Requests still go through FleetClient's backoff.
    func startMonitoring(interval: TimeInterval = 60) {
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

    private func performRefresh() async {
        if let problem = client.configurationProblem {
            if problem != configurationProblem {
                Logger.shared.logError("Fleet: \(problem)")
            }
            configurationProblem = problem
            loadState = .notConfigured
            return
        }
        configurationProblem = nil
        if titles.isEmpty {
            loadState = .loading
        }

        do {
            let fetched = try await client.selfServiceSoftware()
            titles = fetched.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            lastUpdated = Date()
            loadState = .loaded
            // Forget installed versions once inventory has caught up, or Fleet offers a different version
            let awaiting = installedVersionsAwaitingInventory.filter { id, version in
                titles.first { $0.id == id }.map { $0.isUpdateAvailable && $0.availableVersion == version } ?? false
            }
            if awaiting != installedVersionsAwaitingInventory {
                installedVersionsAwaitingInventory = awaiting
            }
            onCatalogUpdated?()
            await detectAppOpenInstalls()
            trackRunningActions()
            // Also follow installs queued elsewhere (Fleet's web page, an admin), but only once per install,
            // so a title stuck pending doesn't keep this polling after the limit
            let pendingIDs = Set(titles.filter(\.isPending).map(\.id))
            if !pendingIDs.isSubset(of: polledPendingIDs) {
                polledPendingIDs.formUnion(pendingIDs)
                startPollingWhilePending()
            }
        } catch let error as FleetError {
            switch error {
            case .ssoRequired:
                loadState = .ssoRequired
            case .notConfigured:
                loadState = .notConfigured
            default:
                // Keep showing the last catalog; the view shows the error alongside it
                loadState = .failed(error.localizedDescription)
            }
            return
        } catch {
            loadState = .failed(error.localizedDescription)
            return
        }

        guard !categoriesUnsupported,
              categoriesFetchedAt.map({ Date().timeIntervalSince($0) > Self.categoriesRefreshInterval }) ?? true else {
            return
        }
        do {
            categories = try await client.selfServiceCategories()
            categoriesFetchedAt = Date()
        } catch FleetError.server(status: 404, _) {
            // Older Fleet servers don't have categories, so don't keep asking
            Logger.shared.logDebug("Fleet: server doesn't support self-service categories")
            categoriesUnsupported = true
        } catch {
            // Categories are optional; the catalog is still usable without them
            categoriesFetchedAt = Date()
        }
    }
}

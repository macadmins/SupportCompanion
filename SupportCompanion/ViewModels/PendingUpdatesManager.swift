//
//  PendingUpdatesManager.swift
//  SupportCompanion
//
//  Created as a base class for all pending-update managers.
//

import Foundation
import Observation

/// Shared timer/task lifecycle for all pending-update managers.
/// Subclasses override `fetchPendingUpdates()`, `fetchPendingUpdatesList()`, and
/// `getInstallPercentage()` to provide MDM-specific data-fetching logic.
@MainActor
@Observable
class PendingUpdatesManager {
    let appState: AppStateManager
    @ObservationIgnored private var updateCheckTask: Task<Void, Never>?
    @ObservationIgnored private var fetchListTask: Task<Void, Never>?
    @ObservationIgnored private var installPercentageTask: Task<Void, Never>?
    @ObservationIgnored private var isInstallPercentageTaskRunning = false

    /// Ids of updates currently being installed from the app, so views can show progress.
    /// Kept in the base class because subclasses can't add observed properties to an @Observable class.
    private(set) var runningUpdateIds: Set<Int> = []

    func markRunning(_ id: Int) {
        runningUpdateIds.insert(id)
    }

    func markFinished(_ id: Int) {
        runningUpdateIds.remove(id)
    }

    init(appState: AppStateManager) {
        self.appState = appState
    }

    // MARK: - Override points

    /// Fetch the pending-update count and send a notification if updates are present.
    func fetchPendingUpdates() async {}

    /// Fetch the full pending-update list.
    func fetchPendingUpdatesList() async {}

    /// Compute and publish the install-percentage value.
    func getInstallPercentage() async {}

    /// The pending updates last fetched by `fetchPendingUpdatesList()`.
    var pendingUpdates: [any PendingUpdate] { [] }

    /// Title of an extra column in the pending updates list, or nil for none.
    var pendingUpdatesDetailColumnTitle: String? { nil }

    /// The app users open to manage software, used by "Open …" buttons and update notifications.
    /// `forUpdates` selects the updates view where the app has a separate one.
    func managementApp(forUpdates: Bool) -> (name: String, path: String) {
        ("Unknown App", "")
    }

    /// Title of the button that opens the management app.
    func openManagementAppTitle(forUpdates: Bool) -> String {
        "\(Constants.Actions.openManagementApp) \(managementApp(forUpdates: forUpdates).name)"
    }

    // MARK: - Shared timer / task management

    final func startUpdateCheckTimer() {
        Logger.shared.logDebug("Starting app update check timer")
        stopUpdateCheckTimer()
        updateCheckTask = Task {
            await fetchPendingUpdates()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3600))
                guard !Task.isCancelled else { break }
                await fetchPendingUpdates()
            }
        }
    }

    final func stopUpdateCheckTimer() {
        Logger.shared.logDebug("Stopping app update check timer")
        updateCheckTask?.cancel()
        updateCheckTask = nil
    }

    final func startFetchingList(interval: TimeInterval = 60) {
        Logger.shared.logDebug("Starting periodic fetch of pending updates list")
        stopFetchingList()
        fetchListTask = Task {
            await fetchPendingUpdatesList()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                Logger.shared.logDebug("Task loop triggered fetch pending updates list")
                await fetchPendingUpdatesList()
            }
        }
    }

    final func stopFetchingList() {
        Logger.shared.logDebug("Stopping periodic fetch of pending updates list")
        fetchListTask?.cancel()
        fetchListTask = nil
    }

    final func startInstallPercentageTask() {
        guard !isInstallPercentageTaskRunning else {
            Logger.shared.logDebug("Install percentage task already running")
            return
        }
        isInstallPercentageTaskRunning = true
        Logger.shared.logDebug("Starting install percentage task")
        installPercentageTask = Task {
            await getInstallPercentage()
            isInstallPercentageTaskRunning = false
        }
    }

    final func stopInstallPercentageTask() {
        Logger.shared.logDebug("Stopping install percentage task")
        installPercentageTask?.cancel()
        installPercentageTask = nil
        isInstallPercentageTaskRunning = false
    }

    deinit {
        updateCheckTask?.cancel()
        fetchListTask?.cancel()
        installPercentageTask?.cancel()
    }
}

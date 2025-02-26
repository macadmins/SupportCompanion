//
//  SystemUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-18.
//

import Foundation

class SystemUpdatesManager: ObservableObject {
    private let appState: AppStateManager
    private var previousUpdateCount: Int = 0
    private var monitorTask: Task<Void, Never>? // Track the monitoring task

    init(appState: AppStateManager) {
        self.appState = appState
    }

    /// Refreshes system update information manually, suitable for `onAppear`.
    func refresh() {
        Task {
            do {
                let result = await ActionHelpers.getSystemUpdateStatus()
                switch result {
                case .success(let (count, updates)):
                    updateCache(count: count, updates: updates)
                case .failure(let error):
                    Logger.shared.logError("Failed to refresh system updates: \(error.localizedDescription)")
                }
            }
        }
    }

    /// Starts monitoring for system update changes.
    func startMonitoring() {
        Logger.shared.logDebug("Starting system updates monitoring")
        stopMonitoring() // Ensure no duplicate monitoring tasks
        monitorTask = Task {
            while !Task.isCancelled {
                do {
                    let result = await ActionHelpers.getSystemUpdateStatus(sendNotification: !appState.preferences.hiddenActions.contains("SoftwareUpdates"))
                    switch result {
                    case .success(let (count, updates)):
                        if count != self.previousUpdateCount {
                            self.previousUpdateCount = count
                            updateCache(count: count, updates: updates)
                        }
                    case .failure(let error):
                        Logger.shared.logError("Monitoring failed to get system updates: \(error.localizedDescription)")
                    }
                }
                // Wait for 1h seconds before checking again
                try? await Task.sleep(nanoseconds: 3600 * 1_000_000_000)
            }
        }
    }

    /// Stops the monitoring task.
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }

    /// Updates the cache in `AppStateManager`.
    private func updateCache(count: Int, updates: [String]) {
        Task { @MainActor in
            let newInfo = SystemUpdates(id: UUID(), count: count, updates: updates)
            self.appState.systemUpdateCache = newInfo
        }
    }
}

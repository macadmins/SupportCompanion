//
//  JamfInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-11-12.
//

import Foundation

class JamfInfoManager: ObservableObject {
	private var monitorTask: Task<Void, Never>?
	private let appStateManager: AppStateManager

    @Published var jamfInfo: JamfInfo

    init(jamfInfo: JamfInfo, appStateManager: AppStateManager) {
        self.jamfInfo = jamfInfo
        self.appStateManager = appStateManager
    }

    func refresh() {
        updateJamfInfo()
    }

    func updateJamfInfo() {
        Task {
            let lastCheckIn = (try? await getLastCheckIn()) ?? "Unknown"
            let lastInventory = (try? await getLastInventoryUpdate()) ?? "Unknown"
            let url = (try? await getJamfUrl()) ?? "Unknown"
            await MainActor.run {
                self.jamfInfo = JamfInfo(
                    lastCheckIn: lastCheckIn,
                    lastInventory: lastInventory,
                    url: url,
                    jamfID: appStateManager.jamfId
                )
            }
        }
    }

    func startMonitoring(interval: TimeInterval = 300) {
        stopMonitoring() // Stop any existing task to avoid duplicates
        Logger.shared.logDebug("Starting jamf info monitoring")
        monitorTask = Task {
            while !Task.isCancelled {
                let lastCheckIn = (try? await getLastCheckIn()) ?? "Unknown"
                let lastInventory = (try? await getLastInventoryUpdate()) ?? "Unknown"
                let url = (try? await getJamfUrl()) ?? "Unknown"

                await MainActor.run {
                    self.jamfInfo = JamfInfo (
                        lastCheckIn: lastCheckIn,
                        lastInventory: lastInventory,
                        url: url,
                        jamfID: appStateManager.jamfId
                    )
                }

                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stops the periodic monitoring task.
    func stopMonitoring() {
        Logger.shared.logDebug("Stopping jamf info monitoring")
        monitorTask?.cancel()
        monitorTask = nil
    }
}

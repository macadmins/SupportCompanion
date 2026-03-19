//
//  JamfInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-11-12.
//

import Foundation

@MainActor
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
            let lastCheckIn: String
            let lastInventory: String
            let url: String

            do {
                lastCheckIn = try await getLastCheckIn()
            } catch {
                Logger.shared.logError("Failed to fetch last check-in: \(error.localizedDescription)")
                lastCheckIn = "Unknown"
            }
            
            do {
                lastInventory = try await getLastInventoryUpdate()
            } catch {
                Logger.shared.logError("Failed to fetch last inventory update: \(error.localizedDescription)")
                lastInventory = "Unknown"
            }

            do {
                url = try await getJamfUrl()
            } catch {
                Logger.shared.logError("Failed to fetch Jamf URL: \(error.localizedDescription)")
                url = "Unknown"
            }

            self.jamfInfo = JamfInfo(
                lastCheckIn: lastCheckIn,
                lastInventory: lastInventory,
                url: url,
                jamfID: appStateManager.jamfId
            )
        }
    }

    func startMonitoring(interval: TimeInterval = 300) {
        stopMonitoring() // Stop any existing task to avoid duplicates
        Logger.shared.logDebug("Starting jamf info monitoring")
        monitorTask = Task {
            while !Task.isCancelled {
                let lastCheckIn: String
                let lastInventory: String
                let url: String

                do {
                    lastCheckIn = try await getLastCheckIn()
                } catch {
                    Logger.shared.logError("Failed to fetch last check-in: \(error.localizedDescription)")
                    lastCheckIn = "Unknown"
                }

                do {
                    lastInventory = try await getLastInventoryUpdate()
                } catch {
                    Logger.shared.logError("Failed to fetch last inventory update: \(error.localizedDescription)")
                    lastInventory = "Unknown"
                }

                do {
                    url = try await getJamfUrl()
                } catch {
                    Logger.shared.logError("Failed to fetch Jamf URL: \(error.localizedDescription)")
                    url = "Unknown"
                }

                self.jamfInfo = JamfInfo(
                    lastCheckIn: lastCheckIn,
                    lastInventory: lastInventory,
                    url: url,
                    jamfID: appStateManager.jamfId
                )

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

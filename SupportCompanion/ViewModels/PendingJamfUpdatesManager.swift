//
//  PendingJamfUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-13.
//

import Foundation
import Combine

class PendingJamfUpdatesManager {
	private var appState: AppStateManager
	private var updateCheckTimer: Timer?
	private var fetchListTimer: Timer?
	private var installPercentageTask: Task<Void, Never>?
	private var isInstallPercentageTaskRunning = false
	private var parser = SSPlusParser()

	init(appState: AppStateManager) {
		self.appState = appState
	}
	
 	nonisolated func getPendingJamfUpdates() async {
		Logger.shared.logDebug("Getting Jamf pending updates")
		
		do {
			if await parser.parse() {
				let (pendingUpdates, _, _) = await computeUpdates(policies: parser.policies, patches: parser.patches, now: Date())
				DispatchQueue.main.async {
					self.appState.pendingJamfUpdates = pendingUpdates
				}
				if pendingUpdates.count > 0 && !appState.preferences.hiddenCards.contains("PendingAppUpdates") {
					NotificationService(appState: appState).sendNotification(
						message: appState.preferences.appUpdateNotificationMessage,
						buttonText: appState.preferences.appUpdateNotificationButtonText,
						command: appState.preferences.appUpdateNotificationCommand,
						notificationType: .appUpdate
					)
				}
			}
		}
	}
	
	func getJamfInstallPercentage() async {
		Logger.shared.logDebug("Getting Jamf install percentage")
		
		do {
			// Fetch counts concurrently
			if await parser.parse() {
				let (_, updateCount, upToDateCount) = await computeUpdates(policies: parser.policies, patches: parser.patches, now: Date())
				let totalApps = updateCount + upToDateCount
				let newInstallPercentage = totalApps > 0
				? (Double(upToDateCount) / Double(totalApps)) * 100
				: 0.0
				
				// Update only if the percentage has changed
				if newInstallPercentage != appState.installPercentage {
					DispatchQueue.main.async {
						self.appState.installedAppsCount = upToDateCount
						self.appState.pendingUpdatesCount = updateCount
						self.appState.installPercentage = newInstallPercentage
						Logger.shared.logDebug("Install percentage updated: \(self.appState.installPercentage)%")
					}
				} else {
					Logger.shared.logDebug("Install percentage unchanged: \(self.appState.installPercentage)%")
				}
			}
		}
	}
	
	func startInstallPercentageTask() {
		guard !isInstallPercentageTaskRunning else {
			Logger.shared.logDebug("Install percentage task already running")
			return
		}

		isInstallPercentageTaskRunning = true
		Logger.shared.logDebug("Starting install percentage task")

		installPercentageTask = Task {
			await self.getJamfInstallPercentage()
			isInstallPercentageTaskRunning = false
		}
	}

	func stopInstallPercentageTask() {
		Logger.shared.logDebug("Stopping install percentage task")
		installPercentageTask?.cancel()
		installPercentageTask = nil
		isInstallPercentageTaskRunning = false
	}

	func startFetchingList(interval: TimeInterval = 60) {
        Logger.shared.logDebug("Starting periodic fetch of pending updates list")

        // Run the task immediately
        Task {
            await getPendingJamfUpdates()
        }

        // Start a periodic timer
        stopFetchingList()
        fetchListTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.logDebug("Timer triggered fetch pending updates list task")
            Task {
                await self?.getPendingJamfUpdates()
            }
        }
    }

	func stopFetchingList() {
        Logger.shared.logDebug("Stopping periodic fetch of pending updates list")
        fetchListTimer?.invalidate()
        fetchListTimer = nil
    }
	
	func startUpdateCheckTimer() {
		Logger.shared.logDebug("Starting app update check timer")

		// Run the task immediately
		Task {
			await getPendingJamfUpdates()
		}

		// Set up the timer to run every hour
		updateCheckTimer?.invalidate() // Stop any existing timer
		updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
			Task {
				await self?.getPendingJamfUpdates()
			}
		}
	}

	func stopUpdateCheckTimer() {
		Logger.shared.logDebug("Stopping app update check timer")
		updateCheckTimer?.invalidate()
		updateCheckTimer = nil
	}
}

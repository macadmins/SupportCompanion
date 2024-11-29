//
//  PendingMunkiUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-21.
//

import Foundation
import Combine

class PendingMunkiUpdatesManager {
    private var appState: AppStateManager
    private let munkiApps = MunkiApps()
    private var updateCheckTimer: Timer?
    private var fetchListTimer: Timer?
    private var installPercentageTask: Task<Void, Never>?
    private var isInstallPercentageTaskRunning = false

    init(appState: AppStateManager) {
        self.appState = appState
    }

    // MARK: - Install Percentage Logic

    func getMunkiInstallPercentage() async {
        Logger.shared.logDebug("Getting Munki install percentage")

        do {
            // Fetch counts concurrently
            async let installedCount = munkiApps.getInstalledAppsCount()
            async let pendingCount = munkiApps.getPendingUpdates()
            let (installed, pending) = await (installedCount, pendingCount)

            let totalApps = installed + pending
            let newInstallPercentage = totalApps > 0
                ? (Double(installed) / Double(totalApps)) * 100
                : 0.0

            // Update only if the percentage has changed
            if newInstallPercentage != appState.installPercentage {
                DispatchQueue.main.async {
                    self.appState.installedAppsCount = installed
                    self.appState.pendingUpdatesCount = pending
                    self.appState.installPercentage = newInstallPercentage
                    Logger.shared.logDebug("Install percentage updated: \(self.appState.installPercentage)%")
                }
            } else {
                Logger.shared.logDebug("Install percentage unchanged: \(self.appState.installPercentage)%")
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
            await self.getMunkiInstallPercentage()
            isInstallPercentageTaskRunning = false
        }
    }

    func stopInstallPercentageTask() {
        Logger.shared.logDebug("Stopping install percentage task")
        installPercentageTask?.cancel()
        installPercentageTask = nil
        isInstallPercentageTaskRunning = false
    }

    // MARK: - Pending Updates Logic

    func fetchPendingUpdatesList() async {
        do {
            let updates = await munkiApps.getPendingUpdatesList()
            DispatchQueue.main.async {
                guard updates != self.appState.pendingMunkiUpdates else {
                    Logger.shared.logDebug("Pending updates list unchanged")
                    return
                }
                self.appState.pendingMunkiUpdates = updates
                Logger.shared.logDebug("Updated pending updates list")
            }
        }
    }
    
    func startFetchingList(interval: TimeInterval = 60) {
        Logger.shared.logDebug("Starting periodic fetch of pending updates list")

        // Run the task immediately
        Task {
            await fetchPendingUpdatesList()
        }

        // Start a periodic timer
        stopFetchingList()
        fetchListTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Logger.shared.logDebug("Timer triggered fetch pending updates list task")
            Task {
                await self?.fetchPendingUpdatesList()
            }
        }
    }

    func stopFetchingList() {
        Logger.shared.logDebug("Stopping periodic fetch of pending updates list")
        fetchListTimer?.invalidate()
        fetchListTimer = nil
    }

    func fetchPendingUpdates() async {
        do {
            let updates = await munkiApps.getPendingUpdates()
            DispatchQueue.main.async {
                if self.appState.pendingUpdatesCount != updates {
                    self.appState.pendingUpdatesCount = updates
                }
            }
            if updates > 0 {
                NotificationService(appState: appState).sendNotification(
                    message: appState.preferences.appUpdateNotificationMessage,
                    buttonText: appState.preferences.appUpdateNotificationButtonText,
                    command: appState.preferences.appUpdateNotificationCommand,
                    notificationType: .appUpdate
                )
            }

            DispatchQueue.main.async {
                self.appState.pendingUpdatesCount = updates
            }
        }
    }

    // MARK: - Timer Logic

    func startUpdateCheckTimer() {
        Logger.shared.logDebug("Starting app update check timer")

        // Run the task immediately
        Task {
            await fetchPendingUpdates()
        }

        // Set up the timer to run every hour
        updateCheckTimer?.invalidate() // Stop any existing timer
        updateCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            Task {
                await self?.fetchPendingUpdates()
            }
        }
    }

    func stopUpdateCheckTimer() {
        Logger.shared.logDebug("Stopping app update check timer")
        updateCheckTimer?.invalidate()
        updateCheckTimer = nil
    }

    // MARK: - Cleanup

    deinit {
        stopInstallPercentageTask()
        stopFetchingList()
    }
}
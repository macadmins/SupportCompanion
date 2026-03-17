//
//  PendingMunkiUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-21.
//

import Foundation
import Combine

class PendingMunkiUpdatesManager: PendingUpdatesManager {
    private let munkiApps = MunkiApps()

    // MARK: - Install Percentage

    override func getInstallPercentage() async {
        Logger.shared.logDebug("Getting Munki install percentage")

        async let installedCount = munkiApps.getInstalledAppsCount()
        async let pendingCount = munkiApps.getPendingUpdates()
        let (installed, pending) = await (installedCount, pendingCount)

        let totalApps = installed + pending
        let newInstallPercentage = totalApps > 0
            ? (Double(installed) / Double(totalApps)) * 100
            : 0.0

        if newInstallPercentage != appState.installPercentage {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.installedAppsCount = installed
                self.appState.pendingUpdatesCount = pending
                self.appState.installPercentage = newInstallPercentage
                Logger.shared.logDebug("Install percentage updated: \(self.appState.installPercentage)%")
            }
        } else {
            Logger.shared.logDebug("Install percentage unchanged: \(appState.installPercentage)%")
        }
    }

    // MARK: - Pending Updates

    override func fetchPendingUpdatesList() async {
        let updates = await munkiApps.getPendingUpdatesList()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard updates != self.appState.pendingMunkiUpdates else {
                Logger.shared.logDebug("Pending updates list unchanged")
                return
            }
            self.appState.pendingMunkiUpdates = updates
            Logger.shared.logDebug("Updated pending updates list")
        }
    }

    override func fetchPendingUpdates() async {
        let updates = await munkiApps.getPendingUpdates()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.appState.pendingUpdatesCount = updates
        }
        if updates > 0 && !appState.preferences.hiddenCards.contains("PendingAppUpdates") {
            NotificationService(appState: appState).sendNotification(
                message: appState.preferences.notifications.appUpdateNotificationMessage,
                buttonText: appState.preferences.notifications.appUpdateNotificationButtonText,
                command: appState.preferences.notifications.appUpdateNotificationCommand,
                notificationType: .appUpdate
            )
        }
    }
}

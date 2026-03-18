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
            appState.installedAppsCount = installed
            appState.pendingUpdatesCount = pending
            appState.installPercentage = newInstallPercentage
            Logger.shared.logDebug("Install percentage updated: \(appState.installPercentage)%")
        } else {
            Logger.shared.logDebug("Install percentage unchanged: \(appState.installPercentage)%")
        }
    }

    // MARK: - Pending Updates

    override func fetchPendingUpdatesList() async {
        let updates = await munkiApps.getPendingUpdatesList()
        guard updates != appState.pendingMunkiUpdates else {
            Logger.shared.logDebug("Pending updates list unchanged")
            return
        }
        appState.pendingMunkiUpdates = updates
        Logger.shared.logDebug("Updated pending updates list")
    }

    override func fetchPendingUpdates() async {
        let updates = await munkiApps.getPendingUpdates()
        appState.pendingUpdatesCount = updates
        if updates > 0 && !appState.preferences.hiddenCards.contains(Constants.Cards.pendingAppUpdates) {
            NotificationService(appState: appState).sendNotification(
                message: appState.preferences.notifications.appUpdateNotificationMessage,
                buttonText: appState.preferences.notifications.appUpdateNotificationButtonText,
                command: appState.preferences.notifications.appUpdateNotificationCommand,
                notificationType: .appUpdate
            )
        }
    }
}

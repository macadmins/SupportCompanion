//
//  PendingIntuneUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation
import Combine

class PendingIntuneUpdatesManager: PendingUpdatesManager {
    private var intuneApps = IntuneApps()

    // MARK: - Install Percentage

    override func getInstallPercentage() async {
        Logger.shared.logDebug("Getting Intune install percentage")

        async let installedCount = intuneApps.getInstalledAppsCountFromLog()
        async let pendingCount = intuneApps.getPendingUpdatesCountFromLog()
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
        let updates = await intuneApps.getPendingUpdatesListFromLog()
        guard updates != appState.pendingIntuneUpdates else {
            Logger.shared.logDebug("Pending updates list unchanged")
            return
        }
        appState.pendingIntuneUpdates = updates
        Logger.shared.logDebug("Updated pending updates list")
    }

    override func fetchPendingUpdates() async {
        let updates = await intuneApps.getPendingUpdatesCountFromLog()
        appState.pendingUpdatesCount = updates
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

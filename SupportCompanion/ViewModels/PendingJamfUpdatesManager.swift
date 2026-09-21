//
//  PendingJamfUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-13.
//

import Foundation
import Combine

class PendingJamfUpdatesManager: PendingUpdatesManager {

    // MARK: - Install Percentage

    override func getInstallPercentage() async {
        Logger.shared.logDebug("Getting Jamf install percentage")
        await refreshSelfService()
        let parser = SSPlusParser()
        guard await parser.parse() else { return }

        let (_, updateCount, upToDateCount) = await computeUpdates(
            policies: parser.policies,
            patches: parser.patches,
            now: Date()
        )
        let totalApps = updateCount + upToDateCount
        let newInstallPercentage = totalApps > 0
            ? (Double(upToDateCount) / Double(totalApps)) * 100
            : 0.0

        if newInstallPercentage != appState.installPercentage {
            appState.installedAppsCount = upToDateCount
            appState.pendingUpdatesCount = updateCount
            appState.installPercentage = newInstallPercentage
            Logger.shared.logDebug("Install percentage updated: \(appState.installPercentage)%")
        } else {
            Logger.shared.logDebug("Install percentage unchanged: \(appState.installPercentage)%")
        }
    }

    // MARK: - Presentation

    override var pendingUpdates: [any PendingUpdate] { appState.pendingJamfUpdates }

    // Text(String) isn't localized automatically, so resolve the "Due by" translation here
    override var pendingUpdatesDetailColumnTitle: String? { String(localized: "Due by") }

    override func managementApp(forUpdates: Bool) -> (name: String, path: String) {
        ("Self Service", Constants.AppPaths.selfService)
    }

    // MARK: - Pending Updates

    override func fetchPendingUpdates() async {
        await getPendingJamfUpdates()
    }

    override func fetchPendingUpdatesList() async {
        await getPendingJamfUpdates()
    }

    func getPendingJamfUpdates() async {
        Logger.shared.logDebug("Getting Jamf pending updates")
        await refreshSelfService()
        let parser = SSPlusParser()
        guard await parser.parse() else { return }

        let (pendingUpdates, _, _) = await computeUpdates(
            policies: parser.policies,
            patches: parser.patches,
            now: Date()
        )
        appState.pendingJamfUpdates = pendingUpdates
        if appState.pendingUpdatesCount != pendingUpdates.count {
            appState.pendingUpdatesCount = pendingUpdates.count
        }
        if pendingUpdates.count > 0 && !appState.preferences.hiddenCards.contains(Constants.Cards.pendingAppUpdates) {
            NotificationService(appState: appState).sendNotification(
                message: appState.preferences.notifications.appUpdateNotificationMessage,
                buttonText: appState.preferences.notifications.appUpdateNotificationButtonText,
                command: appState.preferences.notifications.appUpdateNotificationCommand,
                notificationType: .appUpdate
            )
        }
    }

    // MARK: - Self Service refresh

    func refreshSelfService() async {
        if appState.preferences.refreshSelfService {
            let cmd = ["-gj", Constants.AppPaths.selfService]
            let quitCmd = ["-9", "Self Service+"]
            let checkProcessCmd = ["-x", "Self Service\\+"]
            let checkIfRunning = try? await ExecutionService.executeCommand("/usr/bin/pgrep", with: checkProcessCmd)
            if checkIfRunning == nil {
                _ = try? await ExecutionService.executeCommand("/usr/bin/open", with: cmd)
                try? await Task.sleep(for: .seconds(2))
                _ = try? await ExecutionService.executeCommand("/usr/bin/pkill", with: quitCmd)
            }
        } else {
            Logger.shared.logDebug("Self Service configured to not refresh itself")
        }
    }

    // MARK: - Running state and execution

    func isRunning(patchId: Int) -> Bool {
        runningUpdateIds.contains(patchId)
    }

    func runPatch(patchId: Int, userId: String? = nil) async {
        markRunning(patchId)
        defer { markFinished(patchId) }

        do {
            // The helper runs the patch as whichever user connected to it, which it reads from the
            // audit token rather than taking our word for it.
            _ = try await ExecutionService.jamfSelfServicePatch(id: String(patchId), userId: userId)
        } catch {
            Logger.shared.logError("Failed to run patch \(patchId): \(error)")
        }

        await getPendingJamfUpdates()
    }
}

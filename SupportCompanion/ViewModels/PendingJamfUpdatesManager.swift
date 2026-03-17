//
//  PendingJamfUpdatesManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-13.
//

import Foundation
import Combine

class PendingJamfUpdatesManager: PendingUpdatesManager {
    private var parser = SSPlusParser()

    // Track running patch installs across views/navigation
    @Published private(set) var runningPatchIds: Set<Int> = []

    // MARK: - Install Percentage

    override func getInstallPercentage() async {
        Logger.shared.logDebug("Getting Jamf install percentage")
        await refreshSelfService()
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
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.appState.installedAppsCount = upToDateCount
                self.appState.pendingUpdatesCount = updateCount
                self.appState.installPercentage = newInstallPercentage
                Logger.shared.logDebug("Install percentage updated: \(self.appState.installPercentage)%")
            }
        } else {
            Logger.shared.logDebug("Install percentage unchanged: \(appState.installPercentage)%")
        }
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
        guard await parser.parse() else { return }

        let (pendingUpdates, _, _) = await computeUpdates(
            policies: parser.policies,
            patches: parser.patches,
            now: Date()
        )
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.appState.pendingJamfUpdates = pendingUpdates
            if self.appState.pendingUpdatesCount != pendingUpdates.count {
                self.appState.pendingUpdatesCount = pendingUpdates.count
            }
        }
        if pendingUpdates.count > 0 && !appState.preferences.hiddenCards.contains("PendingAppUpdates") {
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
                sleep(2)
                _ = try? await ExecutionService.executeCommand("/usr/bin/pkill", with: quitCmd)
            }
        } else {
            Logger.shared.logDebug("Self Service configured to not refresh itself")
        }
    }

    // MARK: - Running state and execution

    func isRunning(patchId: Int) -> Bool {
        runningPatchIds.contains(patchId)
    }

    func runPatch(patchId: Int, userId: String? = nil) async {
        await MainActor.run {
            self.runningPatchIds.insert(patchId)
        }
        defer {
            Task { @MainActor in
                self.runningPatchIds.remove(patchId)
            }
        }

        var args: [String] = ["asuser", "504", "/usr/local/bin/jamf", "patch", "-id", String(patchId), "-showSteps", "-selfServiceOnly"]
        if let userId = userId, !userId.isEmpty {
            args += ["-user", userId]
        }

        do {
            _ = try await ExecutionService.executeCommandPrivileged("/bin/launchctl", arguments: args)
        } catch {
            Logger.shared.logError("Failed to run patch \(patchId): \(error)")
        }

        await getPendingJamfUpdates()
    }
}

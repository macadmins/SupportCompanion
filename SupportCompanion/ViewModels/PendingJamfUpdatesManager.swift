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

        let (allUpdates, updateCount, upToDateCount) = await computeUpdates(
            policies: parser.policies,
            patches: parser.patches,
            now: Date()
        )
        // A patch installed from here is done even while the store still offers it, so move it across
        // rather than leaving the ring showing work that is finished.
        let installedButStillListed = updateCount - withoutRecentlyInstalled(allUpdates).count
        let pendingCount = updateCount - installedButStillListed
        let doneCount = upToDateCount + installedButStillListed
        let totalApps = pendingCount + doneCount
        let newInstallPercentage = totalApps > 0
            ? (Double(doneCount) / Double(totalApps)) * 100
            : 0.0

        if newInstallPercentage != appState.installPercentage {
            appState.installedAppsCount = doneCount
            appState.pendingUpdatesCount = pendingCount
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

        let (allUpdates, _, _) = await computeUpdates(
            policies: parser.policies,
            patches: parser.patches,
            now: Date()
        )
        let pendingUpdates = withoutRecentlyInstalled(allUpdates)
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

    /// `pgrep`'s pattern is a regular expression, so the `+` has to be escaped for `-x` to match.
    private static let selfServiceProcessPattern = "Self Service\\+"
    private static let selfServiceProcessName = "Self Service+"

    /// How long to wait for Self Service+ to rewrite its store before giving up on it.
    private static let storeRefreshTimeout: TimeInterval = 20

    func refreshSelfService() async {
        guard appState.preferences.refreshSelfService else {
            Logger.shared.logDebug("Self Service configured to not refresh itself")
            return
        }

        // A running Self Service+ is left alone: it belongs to whoever opened it, and quitting a window
        // somebody is reading to refresh a cache is not a trade worth making. The store then stays as
        // Self Service+ last wrote it, which `RecentlyInstalledPatches` is there to cover.
        if await isSelfServiceRunning() {
            Logger.shared.logDebug("Self Service+ is running; leaving its store as it is for now")
            return
        }

        let storePath = (Constants.Paths.jamfSelfServiceData as NSString).expandingTildeInPath
        let before = storeModifiedDate(at: storePath)

        _ = try? await ExecutionService.executeCommand(
            "/usr/bin/open", with: ["-gj", Constants.AppPaths.selfService]
        )

        await waitForStore(at: storePath, toChangeFrom: before)
        await quitSelfService()
    }

    private func isSelfServiceRunning() async -> Bool {
        // `pgrep` exits non-zero when nothing matches, which ProcessRunner turns into a throw, so a
        // value back means a match.
        let found = try? await ExecutionService.executeCommand(
            "/usr/bin/pgrep", with: ["-x", Self.selfServiceProcessPattern]
        )

        return found != nil
    }

    /// Ask Self Service+ to quit, and insist only if it does not.
    ///
    /// It used to be sent `SIGKILL` outright, which can cut off the store write this refresh exists to
    /// read.
    private func quitSelfService() async {
        _ = try? await ExecutionService.executeCommand(
            "/usr/bin/pkill", with: ["-TERM", Self.selfServiceProcessName]
        )

        for _ in 0..<12 {
            try? await Task.sleep(for: .milliseconds(250))
            if !(await isSelfServiceRunning()) { return }
        }

        Logger.shared.logDebug("Self Service+ did not quit when asked; stopping it")
        _ = try? await ExecutionService.executeCommand(
            "/usr/bin/pkill", with: ["-9", Self.selfServiceProcessName]
        )
    }

    private func storeModifiedDate(at path: String) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }

    /// Wait until Self Service+ has rewritten its store, rather than guessing at how long that takes.
    ///
    /// The previous fixed two seconds was both too short to see new data and long enough to be felt on
    /// every refresh.
    private func waitForStore(at path: String, toChangeFrom before: Date?) async {
        let deadline = Date().addingTimeInterval(Self.storeRefreshTimeout)

        while Date() < deadline {
            try? await Task.sleep(for: .milliseconds(250))

            if let current = storeModifiedDate(at: path), current != before {
                // The mtime changes when the write starts, so let it finish before anything reads it.
                try? await Task.sleep(for: .milliseconds(500))
                return
            }
        }

        Logger.shared.logDebug(
            "Self Service+ did not rewrite its store within \(Int(Self.storeRefreshTimeout))s; using what is there"
        )
    }

    // MARK: - Running state and execution

    func isRunning(patchId: Int) -> Bool {
        runningUpdateIds.contains(patchId)
    }

    func runPatch(patchId: Int, userId: String? = nil) async {
        markRunning(patchId)
        defer { markFinished(patchId) }

        // Taken before the install, because afterwards this patch should be on its way out of the list.
        let installingVersion = appState.pendingJamfUpdates
            .first { $0.patchId == patchId }?.version

        do {
            // The helper runs the patch as whichever user connected to it, which it reads from the
            // audit token rather than taking our word for it.
            _ = try await ExecutionService.jamfSelfServicePatch(id: String(patchId), userId: userId)

            if let installingVersion {
                recentlyInstalled.record(patchId: patchId, version: installingVersion)
            }
        } catch {
            Logger.shared.logError("Failed to run patch \(patchId): \(error)")
        }

        await getPendingJamfUpdates()
    }

    // MARK: - Updates installed but still listed

    /// Patches installed from this app that Self Service+'s store still offers.
    private var recentlyInstalled = RecentlyInstalledPatches()

    /// Hide patches this app has just installed, until the store agrees they are done.
    func withoutRecentlyInstalled(_ updates: [PendingJamfUpdate], now: Date = Date()) -> [PendingJamfUpdate] {
        recentlyInstalled.filtering(updates, now: now)
    }
}

/// Keeps track of patches installed from this app that Self Service+'s store has not caught up with.
///
/// The store is Self Service+'s own cache and only changes when Self Service+ runs, so a patch installed
/// a moment ago keeps appearing in it. Re-deriving the list straight from the store would put the row
/// back with its Update button, which reads as the install having failed. Modelled on the Fleet side's
/// `installedVersionsAwaitingInventory`, which covers the same lag.
///
/// Its own type rather than state on the manager, so the rule can be exercised without an app state.
struct RecentlyInstalledPatches {

    /// How long a patch stays hidden when the store never drops it.
    ///
    /// Long enough to outlast a Self Service+ refresh, short enough that an install which reported
    /// success without taking effect comes back rather than staying hidden.
    static let timeout: TimeInterval = 30 * 60

    private var versions: [Int: String] = [:]
    private var since: [Int: Date] = [:]

    var isEmpty: Bool { versions.isEmpty }

    /// Note that `version` of `patchId` was installed, so it stops being offered as an update.
    mutating func record(patchId: Int, version: String, at date: Date = Date()) {
        versions[patchId] = version
        since[patchId] = date
    }

    /// The updates worth showing, forgetting anything the store has caught up with or waited out.
    mutating func filtering(_ updates: [PendingJamfUpdate], now: Date = Date()) -> [PendingJamfUpdate] {
        for (patchId, version) in versions {
            let stillOffered = updates.contains { $0.patchId == patchId && $0.version == version }
            let waitedTooLong = now.timeIntervalSince(since[patchId] ?? now) >= Self.timeout

            // Gone from the store means Self Service+ has caught up. Waited too long means it has not,
            // and the update is worth showing again rather than hiding indefinitely.
            guard !stillOffered || waitedTooLong else { continue }

            if waitedTooLong && stillOffered {
                Logger.shared.logDebug(
                    "Patch \(patchId) is still offered at \(version) long after installing it; showing it again"
                )
            }

            versions[patchId] = nil
            since[patchId] = nil
        }

        return updates.filter { update in
            guard let patchId = update.patchId else { return true }
            return versions[patchId] != update.version
        }
    }
}

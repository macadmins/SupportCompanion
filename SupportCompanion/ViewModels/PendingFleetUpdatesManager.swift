//
//  PendingFleetUpdatesManager.swift
//  SupportCompanion
//
//  Home cards and update notifications for Fleet mode, from FleetSoftwareManager's catalog.
//

import Foundation

class PendingFleetUpdatesManager: PendingUpdatesManager {
    private var software: FleetSoftwareManager { appState.fleetSoftwareManager }

    // MARK: - Install Percentage

    override func getInstallPercentage() async {
        await software.refreshIfStale()
        publishCounts()
    }

    // MARK: - Presentation

    override var pendingUpdates: [any PendingUpdate] {
        software.updatesAvailable.compactMap(PendingFleetUpdate.init(title:))
    }

    override func managementApp(forUpdates: Bool) -> (name: String, path: String) {
        (Constants.Navigation.apps, "supportcompanion://apps")
    }

    override func catalogSuggestion(for facts: InstallerFacts) -> CatalogSuggestion? {
        suggestion(
            matching: facts,
            in: software.titles.map { CatalogEntry(name: $0.title, bundleIdentifier: $0.bundleIdentifier) }
        )
    }

    /// The apps page is part of this app, so "Open Self Service" would be misleading.
    override func openManagementAppTitle(forUpdates: Bool) -> String {
        forUpdates ? Constants.Fleet.viewUpdates : Constants.Fleet.viewApps
    }

    // MARK: - Pending Updates

    override func fetchPendingUpdatesList() async {
        await software.refreshIfStale()
        publishCounts()
    }

    override func fetchPendingUpdates() async {
        await software.refreshIfStale()
        publishCounts()

        let updates = software.updatesAvailable.compactMap(PendingFleetUpdate.init(title:))
        guard !updates.isEmpty, appState.preferences.fleetNotifyUpdates, !appState.preferences.hiddenCards.contains(Constants.Cards.pendingAppUpdates) else { return }
        let list = updates.map { "\($0.name) \($0.availableVersion)" }.joined(separator: ", ")
        // Clicking the notification shows the updates; its button installs them
        NotificationService(appState: appState).sendNotification(
            message: "\(appState.preferences.notifications.appUpdateNotificationMessage)\n\(list)",
            buttonText: appState.preferences.notifications.appUpdateNotificationButtonText,
            command: NotificationService.fleetUpdateAllCommand,
            openURL: "supportcompanion://apps",
            notificationType: .appUpdate
        )
    }

    /// Updates the counts behind the patch progress cards and the Apps badge.
    func publishCounts() {
        guard software.loadState == .loaded || !software.titles.isEmpty else { return }
        let pending = software.updatesAvailable.count
        let upToDate = software.titles.filter { $0.isInstalled && !software.hasUpdate($0) }.count
        let total = pending + upToDate
        let percentage = total > 0 ? Double(upToDate) / Double(total) * 100 : 0

        if appState.pendingUpdatesCount != pending { appState.pendingUpdatesCount = pending }
        if appState.installedAppsCount != upToDate { appState.installedAppsCount = upToDate }
        if appState.installPercentage != percentage { appState.installPercentage = percentage }
    }
}

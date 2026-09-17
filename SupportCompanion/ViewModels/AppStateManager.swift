//
//  AppStateManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
class AppStateManager {
    static let shared = AppStateManager()
    @ObservationIgnored lazy var systemUpdatesManager = SystemUpdatesManager(appState: self)
    @ObservationIgnored lazy var pendingMunkiUpdatesManager = PendingMunkiUpdatesManager(appState: self)
    @ObservationIgnored lazy var applicationsInfoManager = ApplicationsInfoManager(appState: self)
    @ObservationIgnored lazy var pendingIntuneUpdatesManager = PendingIntuneUpdatesManager(appState: self)
    @ObservationIgnored lazy var pendingJamfUpdatesManager = PendingJamfUpdatesManager(appState: self)
    @ObservationIgnored lazy var pendingFleetUpdatesManager = PendingFleetUpdatesManager(appState: self)
    @ObservationIgnored lazy var evergreenInfoManager = EvergreenInfoManager(appState: self)
    @ObservationIgnored lazy var elevationManager = ElevationManager(appState: self)
    @ObservationIgnored lazy var fleetSoftwareManager: FleetSoftwareManager = {
        let manager = FleetSoftwareManager()
        manager.onActionFinished = { [weak self] title, action, outcome in
            self?.notifyFleetActionFinished(title, action: action, outcome: outcome)
        }
        manager.onCatalogUpdated = { [weak self] in
            self?.pendingFleetUpdatesManager.publishCounts()
        }
        return manager
    }()
    @ObservationIgnored lazy var fleetDeviceManager: FleetDeviceManager = {
        let manager = FleetDeviceManager()
        manager.onNewlyFailing = { [weak self] policies in
            self?.notifyFleetPoliciesFailing(policies)
        }
        manager.onRefetchFinished = { [weak self] in
            Task { await self?.fleetSoftwareManager.refresh() }
        }
        return manager
    }()
    @ObservationIgnored var jsonCardManager: JsonCardManager?
    var isRefreshing: Bool = false
    var jamfId: String = ""
    let deviceInfoManager = DeviceInfoManager.shared
    let storageInfoManager = StorageInfoManager.shared
    let mdmInfoManager = MdmInfoManager.shared
    let batteryInfoManager = BatteryInfoManager.shared
    let ssoInfoManager = SSOInfoManager.shared
    let userInfoManager = UserInfoManager.shared
    let preferences = Preferences()
    var installPercentage: Double = 0.0
    var installedAppsCount: Int = 0
    var pendingUpdatesCount: Int = 0
    var pendingMunkiUpdates: [PendingMunkiUpdate] = []
    var pendingIntuneUpdates: [PendingIntuneUpdate] = []
    var pendingJamfUpdates: [PendingJamfUpdate] = []
    var installedApplications: [InstalledApp] = []
    var systemUpdateCache: SystemUpdates = SystemUpdates(id: UUID(), count: 0, updates: [], hasBackgroundSecurityImprovement: false)
    var windowIsVisible: Bool = false
    var storageUsageColor: Color = Color(NSColor.controlAccentColor)
    var JsonCards: [JsonCard] = []
    var catalogs: [String] = []
    var isDemotionActive: Bool = false
    var timeToDemote: TimeInterval = 0
    @ObservationIgnored var jamfInfoManager: JamfInfoManager!

    @ObservationIgnored private var customCardPathObservation: ObservationToken?
    @ObservationIgnored var showWindowCallback: (() -> Void)?

    /// The pending-updates manager for the configured mode, or nil when the mode has none (System Profiler).
    /// Views and background tasks should go through this rather than checking the mode themselves.
    var activeUpdatesManager: PendingUpdatesManager? {
        switch preferences.mode {
        case Constants.Modes.munki: return pendingMunkiUpdatesManager
        case Constants.Modes.intune: return pendingIntuneUpdatesManager
        case Constants.Modes.jamf: return pendingJamfUpdatesManager
        case Constants.Modes.fleet: return pendingFleetUpdatesManager
        default: return nil
        }
    }

    /// Failing Fleet compliance checks, when the compliance card is shown.
    var fleetFailingChecksCount: Int {
        guard preferences.mode == Constants.Modes.fleet,
              !preferences.hiddenCards.contains(Constants.Cards.fleetPolicies) else { return 0 }
        return fleetDeviceManager.failingPolicies.count
    }

    /// What needs the user's attention, for the menu bar dot and Dock badge: pending app updates, macOS
    /// updates and failing compliance checks, each counted only when its card or button is shown.
    var attentionCount: Int {
        let appUpdates = preferences.hiddenCards.contains(Constants.Cards.pendingAppUpdates) ? 0 : pendingUpdatesCount
        let systemUpdates = preferences.hiddenActions.contains(Constants.Actions.HideStrings.softwareUpdate) ? 0 : systemUpdateCache.count
        return appUpdates + systemUpdates + fleetFailingChecksCount
    }

    func startBackgroundTasks() {
        activeUpdatesManager?.startUpdateCheckTimer()
        if preferences.mode == Constants.Modes.jamf && !preferences.hiddenCards.contains(Constants.Cards.jamfInfo) {
            jamfInfoManager.startMonitoring()
        }
        if preferences.mode == Constants.Modes.fleet {
            fleetDeviceManager.startMonitoring()
        }
        systemUpdatesManager.startMonitoring()
        storageInfoManager.startMonitoring()
        deviceInfoManager.startMonitoring()
    }

    func stopBackgroundTasks() {
        // Stop every manager, not just the active one, in case the mode changed while running
        for manager in [pendingMunkiUpdatesManager, pendingIntuneUpdatesManager, pendingJamfUpdatesManager, pendingFleetUpdatesManager] as [PendingUpdatesManager] {
            manager.stopUpdateCheckTimer()
        }
        fleetDeviceManager.stopMonitoring()
        systemUpdatesManager.stopMonitoring()
        storageInfoManager.stopMonitoring()
        deviceInfoManager.stopMonitoring()
        if !preferences.hiddenCards.contains(Constants.Cards.jamfInfo) && preferences.mode == Constants.Modes.jamf {
            jamfInfoManager.stopMonitoring()
        }
    }

    init() {
        // Initialize jamfInfoManager now that self exists
        self.jamfInfoManager = JamfInfoManager(
            jamfInfo: JamfInfo(lastCheckIn: "", lastInventory: "", url: "", jamfID: ""),
            appStateManager: self
        )

        setupCardManager()

        // Reload custom cards when CustomCardPath changes (Preferences picks up external `defaults write` too)
        customCardPathObservation = observeChanges(
            of: { [unowned self] in self.preferences.customCardPath.trimmingCharacters(in: .whitespacesAndNewlines) },
            onChange: { [weak self] path in self?.customCardPathChanged(to: path) }
        )
    }

    private func customCardPathChanged(to path: String) {
        Logger.shared.logDebug("CustomCardPath changed -> '\(path)'")

        // If path is empty, tear down any existing manager and clear cards
        guard !path.isEmpty else {
            jsonCardManager?.stopWatching()
            jsonCardManager = nil
            JsonCards.removeAll()
            return
        }

        // Ensure a manager exists, stop any current watcher, then load and start watching the new path
        if jsonCardManager == nil {
            jsonCardManager = JsonCardManager(appState: self)
        }
        jsonCardManager?.stopWatching()
        jsonCardManager?.loadFromFile(path)
        jsonCardManager?.watchFile(path)
    }

    func startDemotionTimer(duration: TimeInterval) {
        elevationManager.startDemotionTimer(duration: duration) { [weak self] remainingTime in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.timeToDemote = remainingTime
                self.isDemotionActive = remainingTime > 0
            }
        }
    }

    func stopDemotionTimer() {
        elevationManager.stopDemotionTimer()
        self.timeToDemote = 0
        self.isDemotionActive = false
    }

    private func setupCardManager() {
        guard !preferences.customCardPath.isEmpty else { return }
        if jsonCardManager == nil {
            jsonCardManager = JsonCardManager(appState: self)
        }
        jsonCardManager?.loadFromFile(preferences.customCardPath)
        jsonCardManager?.watchFile(preferences.customCardPath)
    }

    func refreshJsonCards() {
        jsonCardManager?.loadFromFile(preferences.customCardPath)
    }
    
    func refreshAll() {
        isRefreshing = true
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await withTaskGroup(of: Void.self) { group in
                group.addTask { @MainActor in await self.deviceInfoManager.refresh() }
                group.addTask { @MainActor in self.storageInfoManager.refresh() }
                group.addTask { @MainActor in self.mdmInfoManager.refresh() }
                group.addTask { @MainActor in self.systemUpdatesManager.refresh() }
                group.addTask { @MainActor in self.batteryInfoManager.refresh() }
                group.addTask { @MainActor in self.userInfoManager.refresh() }
            }
            self.isRefreshing = false
        }
    }

    private func notifyFleetPoliciesFailing(_ policies: [FleetPolicy]) {
        guard preferences.fleetNotifyPolicies,
              !preferences.hiddenCards.contains(Constants.Cards.fleetPolicies),
              let first = policies.first else { return }
        let message = policies.count == 1
            ? String(format: Constants.Fleet.policyFailingNotification, first.name)
            : String(format: Constants.Fleet.policiesFailingNotification, policies.count, first.name)
        NotificationService(appState: self).sendNotification(
            message: message,
            buttonText: Constants.Fleet.viewDetails,
            command: "open supportcompanion://home",
            notificationType: .generic
        )
    }

    private func notifyFleetActionFinished(_ title: FleetSoftwareTitle, action: FleetSoftwareTitle.Action, outcome: FleetSoftwareManager.ActionOutcome) {
        guard preferences.fleetNotifyInstallResults else { return }
        if outcome == .appOpen {
            // Without a bundle identifier the app can't be found to quit it, so there's no button
            let canQuit = !title.bundleIdentifiers.isEmpty
            NotificationService(appState: self).sendNotification(
                message: String(format: Constants.Fleet.appOpenNotification, title.title),
                buttonText: canQuit ? Constants.Fleet.quitAndUpdate : nil,
                command: canQuit ? "\(NotificationService.fleetQuitAndRetryCommand)\(title.id)" : nil,
                openURL: "supportcompanion://apps",
                notificationType: .generic
            )
            return
        }
        let succeeded = outcome == .succeeded
        let format: String
        switch (action, succeeded) {
        case (.install, true): format = Constants.Fleet.installedNotification
        case (.update, true): format = Constants.Fleet.updatedNotification
        case (.reinstall, true): format = Constants.Fleet.reinstalledNotification
        case (.uninstall, true): format = Constants.Fleet.uninstalledNotification
        case (.uninstall, false): format = Constants.Fleet.uninstallFailedNotification
        case (_, false): format = Constants.Fleet.installFailedNotification
        }
        NotificationService(appState: self).sendNotification(
            message: String(format: format, title.title),
            openURL: "supportcompanion://apps",
            notificationType: .generic
        )
    }
}

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
        manager.onActionFinished = { [weak self] title, action, succeeded in
            self?.notifyFleetActionFinished(title, action: action, succeeded: succeeded)
        }
        manager.onCatalogUpdated = { [weak self] in
            self?.pendingFleetUpdatesManager.publishCounts()
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

    func startBackgroundTasks() {
        activeUpdatesManager?.startUpdateCheckTimer()
        if preferences.mode == Constants.Modes.jamf && !preferences.hiddenCards.contains(Constants.Cards.jamfInfo) {
            jamfInfoManager.startMonitoring()
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

    private func notifyFleetActionFinished(_ title: FleetSoftwareTitle, action: FleetSoftwareTitle.Action, succeeded: Bool) {
        guard preferences.fleetNotifyInstallResults else { return }
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
            notificationType: .generic
        )
    }
}

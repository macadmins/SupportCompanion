//
//  AppStateManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import Combine
import SwiftUI

class AppStateManager: ObservableObject {
    static let shared = AppStateManager()
    lazy var systemUpdatesManager = SystemUpdatesManager(appState: self)
    lazy var pendingMunkiUpdatesManager = PendingMunkiUpdatesManager(appState: self)
    lazy var applicationsInfoManager = ApplicationsInfoManager(appState: self)
    lazy var pendingIntuneUpdatesManager = PendingIntuneUpdatesManager(appState: self)
	lazy var pendingJamfUpdatesManager = PendingJamfUpdatesManager(appState: self)
    lazy var evergreenInfoManager = EvergreenInfoManager(appState: self)
    lazy var elevationManager = ElevationManager(appState: self)
    var jsonCardManager: JsonCardManager?
    @Published var isRefreshing: Bool = false
    @Published var deviceInfoManager = DeviceInfoManager.shared
    @Published var storageInfoManager = StorageInfoManager.shared
    @Published var mdmInfoManager = MdmInfoManager.shared
    @Published var batteryInfoManager = BatteryInfoManager.shared
    @Published var ssoInfoManager = SSOInfoManager.shared
    @Published var userInfoManager = UserInfoManager.shared
    @Published var preferences = Preferences()
    @Published var installPercentage: Double = 0.0
    @Published var installedAppsCount: Int = 0
    @Published var pendingUpdatesCount: Int = 0
    @Published var pendingMunkiUpdates: [PendingMunkiUpdate] = []
    @Published var pendingIntuneUpdates: [PendingIntuneUpdate] = []
	@Published var pendingJamfUpdates: [PendingJamfUpdate] = []
    @Published var installedApplications: [InstalledApp] = []
    @Published var systemUpdateCache: SystemUpdates = SystemUpdates(id: UUID(), count: 0, updates: [])
    @Published var windowIsVisible: Bool = false
    @Published var storageUsageColor: Color = Color(NSColor.controlAccentColor)
    @Published var JsonCards: [JsonCard] = []
    @Published var catalogs: [String] = []
    @Published var isDemotionActive: Bool = false
    @Published var timeToDemote: TimeInterval = 0

    private var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
    private var customPathCancellable: AnyCancellable?
    private var defaultsWatcher: FileWatcher?
    var showWindowCallback: (() -> Void)?

    func startBackgroundTasks() {
        if preferences.mode == Constants.modes.munki {
            pendingMunkiUpdatesManager.startUpdateCheckTimer()
        }
        if preferences.mode == Constants.modes.intune {
            pendingIntuneUpdatesManager.startUpdateCheckTimer()
        }
		if preferences.mode == Constants.modes.jamf {
			pendingJamfUpdatesManager.startUpdateCheckTimer()
		}
        systemUpdatesManager.startMonitoring()
        storageInfoManager.startMonitoring()
        deviceInfoManager.startMonitoring()
    }

    func stopBackgroundTasks() {
        pendingMunkiUpdatesManager.stopUpdateCheckTimer()
        pendingIntuneUpdatesManager.stopUpdateCheckTimer()
        systemUpdatesManager.stopMonitoring()
        storageInfoManager.stopMonitoring()
        deviceInfoManager.stopMonitoring()
    }
    
    init() {
        // Forward changes from `SystemUpdatesManager`
        systemUpdatesManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        storageInfoManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        deviceInfoManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        ssoInfoManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
        
        userInfoManager.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        setupCardManager()

        wirePreferencesObservers()

        // If the Preferences instance is ever replaced, rewire observers
        $preferences
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.wirePreferencesObservers()
            }
            .store(in: &cancellables)

        // Also watch the preferences plist so external `defaults write` changes are picked up live
        setupDefaultsWatcher()
    }

    private func setupDefaultsWatcher() {
        let domain = "com.github.macadmins.SupportCompanion"
        let prefsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(domain).plist")
        let path = prefsURL.path
        defaultsWatcher = FileWatcher(filePath: path) { [weak self] in
            guard let self = self else { return }
            // Read directly from the plist to bypass UserDefaults caching
            if let dict = NSDictionary(contentsOf: prefsURL) as? [String: Any],
               let latest = dict["CustomCardPath"] as? String {
                DispatchQueue.main.async {
                    if self.preferences.customCardPathPublished != latest {
                        Logger.shared.logInfo("Prefs plist changed -> CustomCardPath='\(latest)'")
                        if self.preferences.customCardPath != latest {
                            self.preferences.customCardPath = latest
                        }
                        self.preferences.customCardPathPublished = latest
                    }
                }
            }
        }
    }

    private func wirePreferencesObservers() {
        // Cancel any previous subscription tied to the old preferences instance
        customPathCancellable?.cancel()

        customPathCancellable = preferences.$customCardPathPublished
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .removeDuplicates { (lhs: String, rhs: String) -> Bool in
                lhs == rhs
            }
            .receive(on: RunLoop.main)
            .sink { [weak self] (trimmed: String) in
                guard let self = self else { return }
                Logger.shared.logDebug("CustomCardPath changed -> '\(trimmed)'")

                // If path is empty, tear down any existing manager and clear cards
                guard !trimmed.isEmpty else {
                    self.jsonCardManager?.stopWatching()
                    self.jsonCardManager = nil
                    self.JsonCards.removeAll()
                    return
                }

                // Ensure a manager exists, stop any current watcher, then load and start watching the new path
                if self.jsonCardManager == nil {
                    self.jsonCardManager = JsonCardManager(appState: self)
                }
                self.jsonCardManager?.stopWatching()
                self.jsonCardManager?.loadFromFile(trimmed)
                self.jsonCardManager?.watchFile(trimmed)
            }
    }

    func startDemotionTimer(duration: TimeInterval) {
        elevationManager.startDemotionTimer(duration: duration) { [weak self] remainingTime in
            DispatchQueue.main.async {
                guard let self = self else { return }
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
    
    @MainActor
    func refreshAll() {
        isRefreshing = true
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { self.deviceInfoManager.refresh() }
                group.addTask { self.storageInfoManager.refresh() }
                group.addTask { self.mdmInfoManager.refresh() }
                group.addTask { self.systemUpdatesManager.refresh() }
                group.addTask { self.batteryInfoManager.refresh() }
                group.addTask { self.userInfoManager.refresh() }
            }
            self.isRefreshing = false
        }
    }
}


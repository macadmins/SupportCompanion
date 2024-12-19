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
    lazy var evergreenInfoManager = EvergreenInfoManager(appState: self)
    lazy var elevationManager = ElevationManager(appState: self)
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
    @Published var installedApplications: [InstalledApp] = []
    @Published var systemUpdateCache: SystemUpdates = SystemUpdates(id: UUID(), count: 0, updates: [])
    @Published var windowIsVisible: Bool = false
    @Published var storageUsageColor: Color = Color(NSColor.controlAccentColor)
    @Published var JsonCards: [JsonCard] = []
    @Published var catalogs: [String] = []
    @Published var isDemotionActive: Bool = false
    @Published var timeToDemote: TimeInterval = 0

    private var cancellables: Set<AnyCancellable> = Set<AnyCancellable>()
    var showWindowCallback: (() -> Void)?

    func startBackgroundTasks() {
        if preferences.mode == Constants.modes.munki {
            pendingMunkiUpdatesManager.startUpdateCheckTimer()
        }
        if preferences.mode == Constants.modes.intune {
            pendingIntuneUpdatesManager.startUpdateCheckTimer()
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

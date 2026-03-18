//
//  BatteryInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

@MainActor
class BatteryInfoManager: ObservableObject {
    private var monitorTask: Task<Void, Never>?
    
    static let shared = BatteryInfoManager(
        batteryInfo: BatteryInfo(
            id: UUID(),
            designCapacity: 0,
            maxCapacity: 0,
            cycleCount: 0,
            isCharging: "",
            temperature: 0,
            timeToFull: ""
        )
    )
    
    @Published var batteryInfo: BatteryInfo
    
    init(batteryInfo: BatteryInfo) {
        self.batteryInfo = batteryInfo
    }
    
    func refresh() {
        self.updateBatteryInfo() // Directly call the update method
    }
    
    func updateBatteryInfo() {
        // Ensure all updates happen on the main thread
        self.batteryInfo = BatteryInfo(
            id: UUID(),
            designCapacity: getBatteryDesignCapacity() ?? 0,
            maxCapacity: getBatteryMaxCapacity() ?? 0,
            cycleCount: getBatteryCycleCount() ?? 0,
            isCharging: isBatteryCharging(),
            temperature: getBatteryTemperature() ?? 0,
            timeToFull: getBatteryTimeRemaining()
        )
    }
    
    /// Starts monitoring battery properties and updates the model.
    func startMonitoring(interval: TimeInterval = 60) {
        stopMonitoring() // Stop any existing task to avoid duplicates
        Logger.shared.logDebug("Starting battery monitoring")
        monitorTask = Task {
            while !Task.isCancelled {
                updateBatteryInfo()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    /// Stops the periodic monitoring task.
    func stopMonitoring() {
        Logger.shared.logDebug("Stopping battery monitoring")
        monitorTask?.cancel()
        monitorTask = nil
    }
}

//
//  BatteryHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import IOKit

// MARK: - Battery Properties

func getBatteryDesignCapacity() -> Int? {
    return getBatteryProperty(forKey: "DesignCapacity") as? Int
}

func getBatteryMaxCapacity() -> Int? {
    return getBatteryProperty(forKey: "AppleRawMaxCapacity") as? Int
}

func getBatteryCycleCount() -> Int? {
    return getBatteryProperty(forKey: "CycleCount") as? Int
}

func getBatteryHealthPercentage() -> Double? {
    if let maxCapacity = getBatteryMaxCapacity(),
       let designCapacity = getBatteryDesignCapacity(),
       designCapacity > 0 {
        return (Double(maxCapacity) / Double(designCapacity)) * 100
    }
    return nil
}

func getBatteryTemperature() -> Double? {
    if let temperature = getBatteryProperty(forKey: "Temperature") as? Int {
        // Convert temperature from deciKelvins to Celsius
        return Double(temperature) / 10.0 - 273.15
    }
    return nil
}

func isBatteryCharging() -> String {
    if let isCharging = getBatteryProperty(forKey: "IsCharging") {
        if let boolValue = isCharging as? Bool {
            return boolValue ? Constants.Battery.Labels.charging : Constants.Battery.Labels.notCharging
        }
        
        // Check if the value is an Int (1 for true, 0 for false)
        if let intValue = isCharging as? Int {
            return intValue == 1 ? Constants.Battery.Labels.charging : Constants.Battery.Labels.notCharging
        }
    }
    return "Unknown"
}

func getBatteryTimeRemaining() -> String {
    let isCharging = isBatteryCharging()
    if isCharging != Constants.Battery.Labels.charging{
        return "N/A"
    }
    
    if let timeToFull = getBatteryProperty(forKey: "TimeRemaining") as? Int {
        if timeToFull == 65535 {
            return "N/A"
        }
        return "\(timeToFull) \(Constants.General.minutes)"
    }
    return "Unknown"
}

// MARK: - Helper Methods

private func getBatteryProperty(forKey key: String) -> Any? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != MACH_PORT_NULL else {
        Logger.shared.logError("Unable to find AppleSmartBattery service")
        return nil
    }
    
    defer { IOObjectRelease(service) }

    if let properties = getIOProperties(service: service) {
        return properties[key]
    }

    return nil
}

private func getIOProperties(service: io_service_t) -> [String: Any]? {
    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let props = properties?.takeRetainedValue() as? [String: Any] else {
        return nil
    }
    return props
}


class BatteryMonitor: ObservableObject {
    @Published var batteryTemperature: Double? = nil
    @Published var isCharging: String? = nil
    @Published var cycleCount: Int? = nil
    
    private var monitorTask: Task<Void, Never>? // The background task

    /// Starts monitoring battery properties.
    func startMonitoring() {
        stopMonitoring() // Ensure no duplicate tasks

        monitorTask = Task {
            while !Task.isCancelled {
                do {
                    // Fetch battery data
                    let temperature = getBatteryTemperature()
                    let chargingStatus = isBatteryCharging()
                    let cycleCount = getBatteryCycleCount()

                    // Update the published properties on the main thread
                    await MainActor.run {
                        self.batteryTemperature = temperature
                        self.isCharging = chargingStatus
                        self.cycleCount = cycleCount
                    }
                }

                // Wait for the specified interval before checking again
                try? await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000))
            }
        }
    }

    /// Stops the monitoring task.
    func stopMonitoring() {
        monitorTask?.cancel()
        monitorTask = nil
    }
}

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
    // AppleRawMaxCapacity was removed in macOS 27; FullChargeCapacity is the closest match to
    // the "Maximum Capacity" shown in System Settings
    return (getBatteryProperty(forKey: "AppleRawMaxCapacity") ?? getBatteryProperty(forKey: "FullChargeCapacity")) as? Int
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

/// Nil when the battery doesn't report a temperature (macOS 27 no longer exposes it).
func getBatteryTemperature() -> Double? {
    let celsius: Double
    if let temperature = getBatteryProperty(forKey: "Temperature") as? Int {
        // Older macOS reports deciKelvins in the battery's IORegistry entry
        celsius = Double(temperature) / 10.0 - 273.15
    } else if let sensorTemperature = getBatterySensorTemperature() {
        celsius = sensorTemperature
    } else {
        return nil
    }
    
    // Determine the preferred unit (Celsius or Fahrenheit)
    let locale = Locale.current
    let usesMetric = locale.measurementSystem == .metric
    
    if usesMetric {
        return celsius
    } else {
        let fahrenheit = celsius * 9/5 + 32
        return fahrenheit
    }
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
    let onExternalPower = getBatteryProperty(forKey: "ExternalConnected") as? Bool ?? false
    guard onExternalPower else {
        return "N/A"
    }

    if isBatteryCharging() != Constants.Battery.Labels.charging {
        // On power but not charging: either full, or held below 100% by optimized charging or a charge limit
        let currentCapacity = getBatteryProperty(forKey: "CurrentCapacity") as? Int ?? 0
        let fullyCharged = getBatteryProperty(forKey: "FullyCharged") as? Bool ?? false
        return fullyCharged || currentCapacity >= 100 ? Constants.Battery.Labels.fullyCharged : Constants.Battery.Labels.notCharging
    }

    // 65535 means macOS hasn't estimated the charge time yet
    let estimates = ["AvgTimeToFull", "TimeRemaining"].compactMap { getBatteryProperty(forKey: $0) as? Int }
    if let minutes = estimates.first(where: { $0 > 0 && $0 < 65535 }) {
        return "\(minutes) \(Constants.General.minutes)"
    }
    return Constants.Battery.Labels.calculating
}

// MARK: - HID temperature sensors

// macOS 27 no longer reports the battery temperature in the AppleSmartBattery IORegistry entry.
// The battery's fuel gauge still exposes it as a HID temperature sensor ("gas gauge battery"),
// read through the private IOHIDEventSystemClient API, as tools like Stats do. This is undocumented
// and may change, so callers must handle nil.

private typealias IOHIDEventSystemClientRef = OpaquePointer
private typealias IOHIDServiceClientRef = OpaquePointer
private typealias IOHIDEventRef = OpaquePointer

@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> IOHIDEventSystemClientRef?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: IOHIDEventSystemClientRef, _ matching: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: IOHIDEventSystemClientRef) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: IOHIDServiceClientRef, _ key: CFString) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: IOHIDServiceClientRef, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> IOHIDEventRef?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: IOHIDEventRef, _ field: Int32) -> Double

/// Highest reading from the battery's "gas gauge battery" HID sensors in Celsius, or nil if there are none.
private func getBatterySensorTemperature() -> Double? {
    let temperatureEventType: Int64 = 15 // kIOHIDEventTypeTemperature
    let temperatureField = Int32(temperatureEventType << 16) // kIOHIDEventFieldTemperatureLevel

    guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else {
        return nil
    }
    // Vendor-defined usage page and usage for temperature sensors
    _ = IOHIDEventSystemClientSetMatching(client, ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5] as CFDictionary)

    guard let services = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() as? [AnyObject] else {
        return nil
    }

    let readings: [Double] = services.compactMap { serviceObject in
        let service = OpaquePointer(Unmanaged.passUnretained(serviceObject).toOpaque())
        guard let product = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String,
              product.localizedCaseInsensitiveContains("gas gauge battery"),
              let event = IOHIDServiceClientCopyEvent(service, temperatureEventType, 0, 0) else {
            return nil
        }
        let value = IOHIDEventGetFloatValue(event, temperatureField)
        // Some sensors report garbage (e.g. -9200); only keep plausible battery temperatures
        return (-20...120).contains(value) ? value : nil
    }

    return readings.max()
}

// MARK: - Helper Methods

private func getBatteryProperty(forKey key: String) -> Any? {
    let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
    guard service != MACH_PORT_NULL else {
        Logger.shared.logError("Unable to find AppleSmartBattery service")
        return nil
    }
    
    defer { IOObjectRelease(service) }

    guard let properties = getIOProperties(service: service) else {
        return nil
    }

    // macOS 27 moved most battery values (DesignCapacity, FullChargeCapacity, …) into BatteryData
    if let value = properties[key] {
        return value
    }
    return (properties["BatteryData"] as? [String: Any])?[key]
}

private func getIOProperties(service: io_service_t) -> [String: Any]? {
    var properties: Unmanaged<CFMutableDictionary>?
    guard IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0) == KERN_SUCCESS,
          let props = properties?.takeRetainedValue() as? [String: Any] else {
        return nil
    }
    return props
}

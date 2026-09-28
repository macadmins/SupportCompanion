//
//  HardwareInfoHelpers.swift
//  SupportCompanion
//

import Foundation
import IOKit

func getModelName() -> String {
    return getPropertyValue(forKey: "product-name", service: "product") ?? "Unknown"
}

func getCPUName() -> String? {
    var size: Int = 0
    sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
    var cpuName = [CChar](repeating: 0, count: size)
    sysctlbyname("machdep.cpu.brand_string", &cpuName, &size, nil, 0)
    return String(cString: cpuName)
}

func getRAMSize() -> String {
    let byteCount = ProcessInfo.processInfo.physicalMemory
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = .useGB
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: Int64(byteCount))
}

func getSerialNumber() -> String {
    return getPropertyValue(forKey: "IOPlatformSerialNumber", service: "IOPlatformExpertDevice") ?? "Unknown"
}

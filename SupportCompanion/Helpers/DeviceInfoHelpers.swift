//
//  DeviceInfoHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation

func getHostName() -> String? {
    let hostName = ProcessInfo.processInfo.hostName
    return hostName.isEmpty ? nil : hostName
}

func fetchComputerName() -> String {
    let process = Process()
    let pipe = Pipe()

    process.executableURL = URL(fileURLWithPath: "/usr/sbin/scutil")
    process.arguments = ["--get", "ComputerName"]
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Unknown Hostname"
    } catch {
        Logger.shared.logError("Failed to fetch hostname: \(error)")
        return "Unknown Hostname"
    }
}

func getOSVersion() -> String {
    let os = ProcessInfo.processInfo.operatingSystemVersion
    return "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"
}

func getOSBuild() -> String {
    var osBuildString = ""
    let osBuild = ProcessInfo.processInfo.operatingSystemVersionString
    if let startIndex = osBuild.firstIndex(of: "("),
       let endIndex = osBuild.firstIndex(of: ")") {
        osBuildString = String(osBuild[osBuild.index(after: startIndex)..<endIndex])
    }

    if !osBuildString.isEmpty {
        let parts = osBuildString.split(separator: " ")
        if parts.count > 1 {
            return String(parts[1].trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
    return "Unknown Build"
}

func getCPUType() -> String {
    var sysinfo = utsname()
    uname(&sysinfo)
    let machineMirror = Mirror(reflecting: sysinfo.machine)
    let identifier = machineMirror.children.reduce("") { identifier, element in
        guard let value = element.value as? Int8, value != 0 else { return identifier }
        return identifier + String(UnicodeScalar(UInt8(value)))
    }
    return identifier
}

func getLastRebootDays() -> Int? {
    var mib = [CTL_KERN, KERN_BOOTTIME]
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.stride

    let result = sysctl(&mib, 2, &bootTime, &size, nil, 0)
    guard result == 0 else { return nil }

    let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
    let currentDate = Date()
    let calendar = Calendar.current
    return calendar.dateComponents([.day], from: bootDate, to: currentDate).day
}

func getLastRestartMinutes() -> Int? {
    var mib = [CTL_KERN, KERN_BOOTTIME]
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.stride

    let result = sysctl(&mib, 2, &bootTime, &size, nil, 0)
    guard result == 0 else { return nil }

    let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
    let elapsedMinutes = Int(Date().timeIntervalSince(bootDate) / 60)
    return elapsedMinutes
}

func formattedRebootContent(value: Int) -> String {
    var formattedLastRestart: String {
        if value >= 1440 {
            let days = value / 1440
            return days == 1
                ? "\(days) \(Constants.General.dayAgo)"
                : "\(days) \(Constants.General.daysAgo)"
        } else if value >= 60 {
            let hours = value / 60
            return hours == 1
                ? "\(hours) \(Constants.General.hour)"
                : "\(hours) \(Constants.General.hours)"
        } else {
            return value == 1
                ? "\(value) \(Constants.General.minute)"
                : "\(value) \(Constants.General.minutes)"
        }
    }
    return formattedLastRestart
}

class LastRebootMonitor {
    static let shared = LastRebootMonitor()
    private var updateHandler: ((Int) -> Void)?

    private init() {}

    func startMonitoring(onUpdate: @escaping (Int) -> Void) {
        self.updateHandler = onUpdate
        let lastRebootDays = getLastRestartMinutes()
        DispatchQueue.main.async {
            self.updateHandler?(lastRebootDays ?? 0)
        }
    }
}

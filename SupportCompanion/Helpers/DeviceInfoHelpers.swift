//
//  DeviceInfoHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import IOKit
import Network

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
            osBuildString =  String(osBuild[osBuild.index(after: startIndex)..<endIndex])
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
    guard result == 0 else {
        return nil
    }

    let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
    let currentDate = Date()

    // Calculate the difference in days
    let calendar = Calendar.current
    let daysSinceReboot = calendar.dateComponents([.day], from: bootDate, to: currentDate).day
    
    return daysSinceReboot
}

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

func getAllIPAddresses() -> [String] {
    var ipAddresses: [String] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    // Get the list of all interfaces
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family

            // Check if the address is IPv4 (AF_INET)
            if addrFamily == UInt8(AF_INET) {
                if let currentInterfaceName = interface?.ifa_name {
                    let name = String(cString: currentInterfaceName)

                    // Include only Wi-Fi and Ethernet interfaces
                    if name == "en0" || name.hasPrefix("en") { // Add other Ethernet interfaces if needed
                        // Get the IPv4 address
                        var addr = interface!.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr, socklen_t(interface!.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)

                        let address = String(cString: hostname)
                        ipAddresses.append("\(address)")
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return ipAddresses
}

class IPAddressMonitor {
    private static let monitor = NWPathMonitor()
    private static let queue = DispatchQueue.global(qos: .background)
    private static var lastUpdateTime: Date?

    /// Starts monitoring for IP address changes and calls `onChange` with the updated IPs.
    static func startMonitoring(onChange: @escaping ([String]) -> Void) {
        monitor.pathUpdateHandler = { path in
            let now = Date()
            if let lastUpdate = lastUpdateTime, now.timeIntervalSince(lastUpdate) < 2.0 {
                // Skip updates within 2 seconds
                return
            }
            lastUpdateTime = now

            if path.status == .satisfied {
                let currentIPAddresses = getAllIPAddresses()
                DispatchQueue.main.async {
                    onChange(currentIPAddresses)
                }
            } else {
                DispatchQueue.main.async {
                    onChange(["No network connection"])
                }
            }
        }
        monitor.start(queue: queue)
    }

    static func stopMonitoring() {
        monitor.cancel()
    }
}

class LastRebootMonitor {
    static let shared = LastRebootMonitor()
    private var updateHandler: ((Int) -> Void)?

    private init() {}

    func startMonitoring(onUpdate: @escaping (Int) -> Void) {
        self.updateHandler = onUpdate

        // Check if 24 hours have passed since the last update
        let lastRunKey = "LastRebootMonitorLastRun"
        let defaults = UserDefaults.standard
        let now = Date()

        if let lastRun = defaults.object(forKey: lastRunKey) as? Date, now.timeIntervalSince(lastRun) < 86400 {
            // 24 hours haven't passed, skip this run
            return
        }

        // Update the last run time
        defaults.set(now, forKey: lastRunKey)

        // Perform the reboot check
        let lastRebootDays = getLastRebootDays()
        DispatchQueue.main.async {
            self.updateHandler?(lastRebootDays ?? 0)
        }
    }
}

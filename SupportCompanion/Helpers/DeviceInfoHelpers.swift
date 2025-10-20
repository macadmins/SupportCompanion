//
//  DeviceInfoHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import IOKit
import Network
import CoreWLAN

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

func getLastRestartMinutes() -> Int? {
    var mib = [CTL_KERN, KERN_BOOTTIME]
    var bootTime = timeval()
    var size = MemoryLayout<timeval>.stride

    let result = sysctl(&mib, 2, &bootTime, &size, nil, 0)
    guard result == 0 else {
        return nil
    }

    let bootDate = Date(timeIntervalSince1970: TimeInterval(bootTime.tv_sec))
    let currentDate = Date()

    let elapsedMinutes = Int(currentDate.timeIntervalSince(bootDate) / 60)
    return elapsedMinutes
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

func getSSID() -> String? {
    // Helper to synchronously call async ExecutionService methods
    func runCommand(_ launchPath: String, _ arguments: [String], privileged: Bool = false) throws -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<String, Error> = .failure(NSError(domain: "ExecutionService", code: -1))

        let execute: () async throws -> String = {
            if privileged {
                return try await ExecutionService.executeCommandPrivileged(launchPath, arguments: arguments)
            } else {
                return try await ExecutionService.executeCommand(launchPath, with: arguments)
            }
        }

        Task {
            do {
                let output = try await execute()
                result = .success(output)
            } catch {
                result = .failure(error)
            }
            semaphore.signal()
        }

        // Wait until task completes
        semaphore.wait()

        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    do {
        // Enable verbose temporarily; ignore failures
        // only continue if wifi is on
		guard let wifi = CWWiFiClient.shared().interface() else { return "WiFi Off" }
		guard wifi.powerOn() else { return "WiFi Off" }

        do {
            _ = try runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 1"], privileged: true)
        } catch {
            _ = try? runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 1"], privileged: true)
        }

        // Correctly pass the pipeline to /bin/sh -c without extra quoting
        let command = "/usr/sbin/ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}'"
        let ssid = try runCommand("/bin/sh", ["-c", command])

        // Disable verbose; ignore failures
        _ = try? runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 0"], privileged: true)

        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        // if trimmed == <redacted> change to nil
        if trimmed == "<redacted>" {
            return nil
        }
        return trimmed.isEmpty ? nil : trimmed
    } catch {
        Logger.shared.logError("Failed to fetch SSID: \(error)")
        // Ensure we attempt to reset verbose mode even on failure
        _ = try? runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 0"], privileged: true)
        return nil
    }
}

class IPAddressMonitor {
    private static let monitor = NWPathMonitor()
    private static let queue = DispatchQueue.global(qos: .background)
    private static var lastUpdateTime: Date?
    private static var lastIPs: [String] = []
	
	struct NetworkStatus {
		let ipAddresses: [String]
		let ssid: String?
	}
    /// Starts monitoring for IP address changes and calls `onChange` with the updated IPs.
    static func startMonitoring(onChange: @escaping (NetworkStatus) -> Void) {
        monitor.pathUpdateHandler = { path in
            // Only proceed when we have a reachable path. If not reachable, treat as empty IP list.
            let currentIPs: [String]
            let currentSSID: String?

            if path.status == .satisfied {
                currentIPs = getAllIPAddresses()
                currentSSID = getSSID()
            } else {
                currentIPs = []
                currentSSID = nil
            }

            // Compare sorted lists to be order-insensitive
            if currentIPs.sorted() != lastIPs.sorted() {
                lastIPs = currentIPs
                DispatchQueue.main.async {
                    onChange(NetworkStatus(ipAddresses: currentIPs, ssid: currentSSID))
                }
            }
        }
        monitor.start(queue: queue)
    }

    static func stopMonitoring() {
        monitor.cancel()
    }
}

func formattedRebootContent(value: Int) -> String {
    var formattedLastRestart: String {
        if value >= 1440 { // 1440 minutes in a day
            let days = value / 1440
            if days == 1 {
                return "\(days) \(Constants.General.dayAgo)"
            }
            return "\(days) \(Constants.General.daysAgo)"
        } else if value >= 60 { // More than an hour
            let hours = value / 60
            if hours == 1 {
                return "\(hours) \(Constants.General.hour)"
            }
            return "\(hours) \(Constants.General.hours)"
        } else { // Less than an hour
            if value == 1 {
                return "\(value) \(Constants.General.minute)"
            }
            return "\(value) \(Constants.General.minutes)"
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

        // Perform the reboot check
        let lastRebootDays = getLastRestartMinutes()
        DispatchQueue.main.async {
            self.updateHandler?(lastRebootDays ?? 0)
        }
    }
}


//
//  NetworkInfoHelpers.swift
//  SupportCompanion
//

import Foundation
import Network
import CoreWLAN

func getAllIPAddresses() -> [String] {
    var ipAddresses: [String] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            guard let interface = ptr?.pointee else { 
                Logger.shared.logError("Failed to get interface information")
                return ipAddresses
            }
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                if let currentInterfaceName = interface.ifa_name {
                    let name = String(cString: currentInterfaceName)
                    if name == "en0" || name.hasPrefix("en") {
                        var addr = interface.ifa_addr.pointee
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                        ipAddresses.append(String(cString: hostname))
                    }
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return ipAddresses
}

func getSSID() async -> String? {
    guard let wifi = CWWiFiClient.shared().interface() else { return "WiFi Off" }
    guard wifi.powerOn() else { return "WiFi Off" }

    _ = try? await ExecutionService.executeCommandPrivileged(
        "/bin/sh", arguments: ["-c", "/usr/sbin/ipconfig setverbose 1"]
    )

    do {
        let command = "/usr/sbin/ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}'"
        let ssid = try await ExecutionService.executeCommand("/bin/sh", with: ["-c", command])
        _ = try? await ExecutionService.executeCommandPrivileged(
            "/bin/sh", arguments: ["-c", "/usr/sbin/ipconfig setverbose 0"]
        )
        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "<redacted>" { return nil }
        return trimmed.isEmpty ? nil : trimmed
    } catch {
        Logger.shared.logError("Failed to fetch SSID: \(error)")
        _ = try? await ExecutionService.executeCommandPrivileged(
            "/bin/sh", arguments: ["-c", "/usr/sbin/ipconfig setverbose 0"]
        )
        return nil
    }
}

class IPAddressMonitor {
    private static var monitor = NWPathMonitor()
    private static let queue = DispatchQueue.global(qos: .background)
    private static var lastUpdateTime: Date?
    private static var lastIPs: [String] = []

    struct NetworkStatus {
        let ipAddresses: [String]
        let ssid: String?
    }

    static func startMonitoring(onChange: @escaping (NetworkStatus) async -> Void) {
        monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let currentIPs = path.status == .satisfied ? getAllIPAddresses() : [String]()
            guard currentIPs.sorted() != lastIPs.sorted() else { return }
            lastIPs = currentIPs
            Task {
                let currentSSID = path.status == .satisfied ? await getSSID() : nil
                await onChange(NetworkStatus(ipAddresses: currentIPs, ssid: currentSSID))
            }
        }
        monitor.start(queue: queue)
    }

    static func stopMonitoring() {
        monitor.cancel()
    }
}

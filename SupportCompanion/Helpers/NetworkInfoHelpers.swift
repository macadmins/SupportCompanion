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

            //let interface = ptr?.pointee
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

func getSSID() -> String? {
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

        semaphore.wait()

        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }

    do {
        guard let wifi = CWWiFiClient.shared().interface() else { return "WiFi Off" }
        guard wifi.powerOn() else { return "WiFi Off" }

        do {
            _ = try runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 1"], privileged: true)
        } catch {
            _ = try? runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 1"], privileged: true)
        }

        let command = "/usr/sbin/ipconfig getsummary en0 | awk -F ' SSID : ' '/ SSID : / {print $2}'"
        let ssid = try runCommand("/bin/sh", ["-c", command])

        _ = try? runCommand("/bin/sh", ["-c", "/usr/sbin/ipconfig setverbose 0"], privileged: true)

        let trimmed = ssid.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "<redacted>" {
            return nil
        }
        return trimmed.isEmpty ? nil : trimmed
    } catch {
        Logger.shared.logError("Failed to fetch SSID: \(error)")
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

    static func startMonitoring(onChange: @escaping (NetworkStatus) -> Void) {
        monitor.pathUpdateHandler = { path in
            let currentIPs: [String]
            let currentSSID: String?

            if path.status == .satisfied {
                currentIPs = getAllIPAddresses()
                currentSSID = getSSID()
            } else {
                currentIPs = []
                currentSSID = nil
            }

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

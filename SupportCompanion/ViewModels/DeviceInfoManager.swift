//
//  DeviceInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import Combine

class DeviceInfoManager: ObservableObject {
    private var timer: AnyCancellable?

    static let shared = DeviceInfoManager(
        deviceInfo: DeviceInfo(
            id: UUID(),
            hostName: "",
            osVersion: "",
            osBuild: "",
            cpuType: "",
            ram: "",
            ipAddress: "",
            serialNumber: "",
            lastRestart: 0,
            model: ""
        )
    )
    
    @Published var deviceInfo: DeviceInfo? = nil
    
    init(deviceInfo: DeviceInfo) {
        self.deviceInfo = deviceInfo
    }

    func startMonitoring() {
        Logger.shared.logDebug("Starting device info monitoring")
        refresh()
        timer = Timer.publish(every: 86400, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                self.refresh()
            }
    }

    func stopMonitoring() {
        Logger.shared.logDebug("Stopping device info monitoring")
        timer?.cancel()
    }
    
    func refresh() {
        DispatchQueue.main.async {
            let currentIPAddress = getAllIPAddresses().joined(separator: ", ")
            self.deviceInfo = DeviceInfo(
                id: UUID(),
                hostName: fetchComputerName(),
                osVersion: getOSVersion(),
                osBuild: getOSBuild(),
                cpuType: getCPUName() ?? "",
                ram: getRAMSize(),
                ipAddress: currentIPAddress,
                serialNumber: getSerialNumber(),
                lastRestart: getLastRebootDays() ?? 0,
                model: getModelName()
            )
        }
        
        LastRebootMonitor.shared.startMonitoring { [weak self] lastRebootDays in
            guard let self = self else { return }
            
            DispatchQueue.global(qos: .background).async {
                
                DispatchQueue.main.async {
                    guard let currentDeviceInfo = self.deviceInfo else {
                        return
                    }
                    
                    if currentDeviceInfo.lastRestart != lastRebootDays {
                        self.deviceInfo = DeviceInfo(
                            id: currentDeviceInfo.id,
                            hostName: currentDeviceInfo.hostName,
                            osVersion: currentDeviceInfo.osVersion,
                            osBuild: currentDeviceInfo.osBuild,
                            cpuType: currentDeviceInfo.cpuType,
                            ram: currentDeviceInfo.ram,
                            ipAddress: currentDeviceInfo.ipAddress,
                            serialNumber: currentDeviceInfo.serialNumber,
                            lastRestart: lastRebootDays,
                            model: currentDeviceInfo.model
                        )
                    }
                }
            }
        }
        
        IPAddressMonitor.startMonitoring { newIPAddresses in
            DispatchQueue.main.async {
                guard let currentDeviceInfo = self.deviceInfo else {
                    return // Exit early if `self.deviceInfo` is nil
                }

                let updatedIPAddress = newIPAddresses.joined(separator: ", ")
                self.deviceInfo = DeviceInfo(
                    id: currentDeviceInfo.id,
                    hostName: currentDeviceInfo.hostName,
                    osVersion: currentDeviceInfo.osVersion,
                    osBuild: currentDeviceInfo.osBuild,
                    cpuType: currentDeviceInfo.cpuType,
                    ram: currentDeviceInfo.ram,
                    ipAddress: updatedIPAddress,
                    serialNumber: currentDeviceInfo.serialNumber,
                    lastRestart: currentDeviceInfo.lastRestart,
                    model: currentDeviceInfo.model
                )
            }
        }
    }
}

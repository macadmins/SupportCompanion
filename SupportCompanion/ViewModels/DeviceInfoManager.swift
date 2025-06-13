//
//  DeviceInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import Combine

class DeviceInfoManager: ObservableObject {
    //private var timer: AnyCancellable?
    private var timer: Timer?

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
            lastRestartDays: 0,
            model: ""
        )
    )
    
    @Published var deviceInfo: DeviceInfo? = nil
    
    init(deviceInfo: DeviceInfo) {
        self.deviceInfo = deviceInfo
    }

    func startMonitoring() {
        Logger.shared.logDebug("Starting device info monitoring")
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in
            self.refresh()
        }
    }

    func stopMonitoring() {
        Logger.shared.logDebug("Stopping device info monitoring")
        timer?.invalidate()
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
                lastRestart: getLastRestartMinutes() ?? 0,
                lastRestartDays: getLastRebootDays() ?? 0,
                model: getModelName()
            )
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
                    lastRestartDays: currentDeviceInfo.lastRestartDays,
                    model: currentDeviceInfo.model
                )
            }
        }
    }
}

//
//  DeviceInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import Combine

class DeviceInfoManager: ObservableObject {
    private var monitorTask: Task<Void, Never>?
    
    static let shared = DeviceInfoManager(
        deviceInfo: DeviceInfo(
            id: UUID(),
            hostName: "",
            osVersion: "",
            osBuild: "",
            cpuType: "",
            ram: "",
            ipAddress: "",
            ssid: nil,
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
        stopMonitoring()
        refresh()
        monitorTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                refresh()
            }
        }
    }

    func stopMonitoring() {
        Logger.shared.logDebug("Stopping device info monitoring")
        monitorTask?.cancel()
        monitorTask = nil
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
                ssid: getSSID(),
                serialNumber: getSerialNumber(),
                lastRestart: getLastRestartMinutes() ?? 0,
                lastRestartDays: getLastRebootDays() ?? 0,
                model: getModelName()
            )
            
            guard let lastRebootDays = self.deviceInfo?.lastRestartDays else {
                return
            }
            if lastRebootDays >= AppStateManager.shared.preferences.notifications.rebootReminderDays && AppStateManager.shared.preferences.notifications.rebootReminderDays > 0 {
                let dayWord = lastRebootDays == 1 ? Constants.General.day : Constants.General.days
                let message = String(format: Constants.Notifications.Reboot.RebootMessage, lastRebootDays, dayWord.lowercased())

                NotificationService(appState: AppStateManager.shared).sendNotification(
                    message: message,
                    buttonText: "",
                    command: "",
                    notificationType: .rebootReminder
                )
            }
        }
        
        IPAddressMonitor.startMonitoring { status in
            DispatchQueue.main.async {
                guard let currentDeviceInfo = self.deviceInfo else {
                    return // Exit early if `self.deviceInfo` is nil
                }

				let updatedIPAddress = status.ipAddresses.joined(separator: ", ")
                self.deviceInfo = DeviceInfo(
                    id: currentDeviceInfo.id,
                    hostName: currentDeviceInfo.hostName,
                    osVersion: currentDeviceInfo.osVersion,
                    osBuild: currentDeviceInfo.osBuild,
                    cpuType: currentDeviceInfo.cpuType,
                    ram: currentDeviceInfo.ram,
                    ipAddress: updatedIPAddress,
					ssid: status.ssid,
                    serialNumber: currentDeviceInfo.serialNumber,
                    lastRestart: currentDeviceInfo.lastRestart,
                    lastRestartDays: currentDeviceInfo.lastRestartDays,
                    model: currentDeviceInfo.model
                )
            }
        }
    }
}


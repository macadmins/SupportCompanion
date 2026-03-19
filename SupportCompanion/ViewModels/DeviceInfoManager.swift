//
//  DeviceInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import Combine

@MainActor
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

        IPAddressMonitor.startMonitoring { @MainActor [weak self] status in
            guard let self, let currentDeviceInfo = self.deviceInfo else { return }
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

        monitorTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(300))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
    }

    func stopMonitoring() {
        Logger.shared.logDebug("Stopping device info monitoring")
        monitorTask?.cancel()
        IPAddressMonitor.stopMonitoring()
        monitorTask = nil
    }
    
    func refresh() async {
        let currentIPAddress = getAllIPAddresses().joined(separator: ", ")
        deviceInfo = DeviceInfo(
            id: UUID(),
            hostName: fetchComputerName(),
            osVersion: getOSVersion(),
            osBuild: getOSBuild(),
            cpuType: getCPUName() ?? "",
            ram: getRAMSize(),
            ipAddress: currentIPAddress,
            ssid: await getSSID(),
            serialNumber: getSerialNumber(),
            lastRestart: getLastRestartMinutes() ?? 0,
            lastRestartDays: getLastRebootDays() ?? 0,
            model: getModelName()
        )

        if let lastRebootDays = deviceInfo?.lastRestartDays,
            lastRebootDays >= AppStateManager.shared.preferences.notifications.rebootReminderDays,
            AppStateManager.shared.preferences.notifications.rebootReminderDays > 0 {
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
}


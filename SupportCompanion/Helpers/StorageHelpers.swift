//
//  StorageHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

// Get the name of the main storage volume
func getStorageName() -> String {
    let fileURL = URL(fileURLWithPath:"/")
    do {
        let name = try fileURL.resourceValues(forKeys: [.volumeNameKey])
        return name.volumeName ?? ""
    } catch {
        Logger.shared.logError("Error fetching storage usage: \(error)")
    }
    return ""
}

func getStorageUsagePercentage() -> Double {
    let fileURL = URL(fileURLWithPath: "/")
    do {
        // Fetch resource values for total and available capacity
        let values = try fileURL.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey])
        if let totalSpace = values.volumeTotalCapacity, let freeSpace = values.volumeAvailableCapacityForImportantUsage {
            Logger.shared.logDebug("Free space: \(freeSpace), Total space: \(totalSpace)")
            // Convert totalSpace to Int64 for compatibility
            let usedSpace = Int64(totalSpace) - freeSpace
            return ((Double(usedSpace) / Double(totalSpace)) * 100).rounded(toPlaces: 1)
        }
    } catch {
        Logger.shared.logError("Fallback to 0% storage usage: \(error)")
    }
    return 0.0
}

// Check if FileVault is enabled
func isFileVaultEnabled() -> Bool {
    let fileVaultStatus = Process()
    fileVaultStatus.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
    fileVaultStatus.arguments = ["status"]
    
    let pipe = Pipe()
    fileVaultStatus.standardOutput = pipe
    
    do {
        try fileVaultStatus.run()
        fileVaultStatus.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return output.contains("FileVault is On")
    } catch {
        Logger.shared.logError("Error checking FileVault status: \(error)")
    }
    return false
}

class StorageMonitor {
    static let shared = StorageMonitor()
    private var timer: Timer?
    private var updateHandler: ((Double) -> Void)?

    private init() {}

    func startMonitoring(interval: TimeInterval = 60, onUpdate: @escaping (Double) -> Void) {
        stopMonitoring() // Stop any existing timer
        self.updateHandler = onUpdate

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            let usagePercentage = getStorageUsagePercentage()
            DispatchQueue.main.async {
                self.updateHandler?(usagePercentage)
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
}

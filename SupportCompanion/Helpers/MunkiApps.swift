//
//  MunkiApps.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

class MunkiApps {
    private let logger = Logger.shared // Replace with your logging service
    private let managedInstallsReportPlist = "/Library/Managed Installs/ManagedInstallReport.plist"
    private let selfServeManifest = "/Library/Managed Installs/manifests/SelfServeManifest"
    
    /// Attempts to read a file with retries
    private func readFileWithRetry(filePath: String, maxRetries: Int = 3, delayMilliseconds: Int = 20000) async throws -> Data? {
        for attempt in 1...maxRetries {
            do {
                return try Data(contentsOf: URL(fileURLWithPath: filePath))
            } catch {
                if attempt < maxRetries {
                    logger.logDebug("File \(filePath) not available. Retrying in \(delayMilliseconds)ms.")
                    try await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
                } else {
                    logger.logError("File \(filePath) could not be opened after \(maxRetries) attempts.")
                    throw error
                }
            }
        }
        return nil
    }
    
    /// Ensures a file exists with retries
    private func lookForFileWithRetry(filePath: String, maxRetries: Int = 3, delayMilliseconds: Int = 2000) async throws {
        for attempt in 1...maxRetries {
            if FileManager.default.fileExists(atPath: filePath) {
                return
            }
            if attempt < maxRetries {
                logger.logDebug("File \(filePath) not found. Retrying in \(delayMilliseconds)ms.")
                try await Task.sleep(nanoseconds: UInt64(delayMilliseconds) * 1_000_000)
            } else {
                logger.logError("File \(filePath) could not be found after \(maxRetries) attempts.")
                throw NSError(domain: "MunkiApps", code: 1, userInfo: [NSLocalizedDescriptionKey: "File not found"])
            }
        }
    }
    
    /// Reads a plist and parses it into a dictionary
    private func readPlist(filePath: String) async throws -> [String: Any] {
        try await lookForFileWithRetry(filePath: filePath)
        guard let data = try await readFileWithRetry(filePath: filePath) else {
            logger.logError("Failed to read file: \(filePath)")
            throw NSError(domain: "MunkiApps", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to read file"])
        }
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let dictionary = plist as? [String: Any] else {
            logger.logError("Invalid plist format for file: \(filePath)")
            throw NSError(domain: "MunkiApps", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid plist format"])
        }
        return dictionary
    }

    /// Returns the count of pending updates
    func getPendingUpdates() async -> Int {
        do {
            let plist = try await readPlist(filePath: managedInstallsReportPlist)
            if let itemsToInstall = plist["ItemsToInstall"] as? [Any] {
                return itemsToInstall.count
            } else {
                logger.logDebug("ItemsToInstall key not found")
                return 0
            }
        } catch {
            logger.logError("Error fetching pending updates: \(error)")
            return 0
        }
    }
    
    /// Returns the count of installed apps
    func getInstalledAppsCount() async -> Int {
        do {
            let plist = try await readPlist(filePath: managedInstallsReportPlist)
            if let installedItems = plist["InstalledItems"] as? [Any] {
                return installedItems.count
            } else {
                logger.logDebug("InstalledItems key not found")
                return 0
            }
        } catch {
            logger.logError("Error fetching installed apps count: \(error)")
            return 0
        }
    }
    
    /// Returns a list of pending updates
    func getPendingUpdatesList() async -> [PendingMunkiUpdate] {
        do {
            let plist = try await readPlist(filePath: managedInstallsReportPlist)
            if let itemsToInstall = plist["ItemsToInstall"] as? [[String: Any]] {
                return itemsToInstall.compactMap { appDict in
                    guard let name = appDict["display_name"] as? String,
                          let version = appDict["version_to_install"] as? String else {
                        return nil
                    }
                    return PendingMunkiUpdate(name: name, version: version)
                }
            } else {
                logger.logDebug("ItemsToInstall key not found")
                return []
            }
        } catch {
            logger.logError("Error fetching pending updates list: \(error)")
            return []
        }
    }
    
    /// Returns a list of installed apps
    func getInstalledAppsList() async -> [[String: Any]] {
        do {
            let plist = try await readPlist(filePath: managedInstallsReportPlist)
            if let managedInstalls = plist["ManagedInstalls"] as? [[String: Any]] {
                return managedInstalls
            } else {
                logger.logDebug("ManagedInstalls key not found")
                return []
            }
        } catch {
            logger.logError("Error fetching installed apps list: \(error)")
            return []
        }
    }
    
    /// Returns a list of self-serve apps
    func getSelfServeAppsList() async -> [String] {
        do {
            let plist = try await readPlist(filePath: selfServeManifest)
            if let managedInstalls = plist["managed_installs"] as? [String] {
                return managedInstalls
            } else {
                logger.logDebug("managed_installs key not found")
                return []
            }
        } catch {
            logger.logError("Error fetching self-serve apps list: \(error)")
            return []
        }
    }
}

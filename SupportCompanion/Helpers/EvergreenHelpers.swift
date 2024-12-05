//
//  Evergreen.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-28.
//

import Foundation

class EvergreenHelpers {
    private var catalogs: [String] = []
    private let manifestDirectory = "/Library/Managed Installs/manifests"
    
    func getCatalogs() async -> [String] {
        do {
            // Fetch serial number
            let serialNumber = getSerialNumber()
            let deviceManifest = (manifestDirectory as NSString).appendingPathComponent(serialNumber.trimmingCharacters(in: .whitespacesAndNewlines))
            
            // Check if the device manifest exists
            if FileManager.default.fileExists(atPath: deviceManifest) {
                do {
                    // Read the device manifest
                    let data = try Data(contentsOf: URL(fileURLWithPath: deviceManifest))
                    if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                       let catalogsList = plist["catalogs"] as? [String] {
                        catalogs.append(contentsOf: catalogsList)
                    } else {
                        Logger.shared.logDebug("Device manifest does not contain catalogs key")
                    }
                } catch {
                    Logger.shared.logError("Failed to read device manifest: \(error.localizedDescription)")
                }
            } else {
                Logger.shared.logInfo("Device manifest not found")
            }
        }
        
        return catalogs
    }
}

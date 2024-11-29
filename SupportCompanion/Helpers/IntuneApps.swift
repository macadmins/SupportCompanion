//
//  IntuneApps.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation
import SQLite3

class IntuneApps {
    private let sidecarDBPath = "/Library/Application Support/Microsoft/Intune/SideCar/sidecar.sqlite"
    private let sidecarQuery = "SELECT ZPOLICYRESULTJSON FROM ZAPPSTATECHANGEITEM"
    //private weak var appState: AppStateManager?

    /*init(appState: AppStateManager) {
        self.appState = appState
    }*/

    // Fetch Intune apps and their policies as a list of dictionaries
    func fetchIntuneApps() async -> [[String: Any]] {
        var apps: [[String: Any]] = []

        guard FileManager.default.fileExists(atPath: sidecarDBPath) else {
            Logger.shared.logError("Intune database not found at \(sidecarDBPath)")
            return apps
        }

        var db: OpaquePointer?
        guard sqlite3_open(sidecarDBPath, &db) == SQLITE_OK, let database = db else {
            Logger.shared.logError("Failed to open database at \(sidecarDBPath)")
            return apps
        }
        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sidecarQuery, -1, &statement, nil) == SQLITE_OK, let queryStatement = statement else {
            Logger.shared.logError("Failed to prepare query: \(sidecarQuery)")
            return apps
        }
        defer { sqlite3_finalize(queryStatement) }

        while sqlite3_step(queryStatement) == SQLITE_ROW {
            if let policyDict = parseRow(statement: queryStatement, columnIndex: 0) {
                apps.append(policyDict)
            }
        }

        return apps
    }
    
    func getInstalledAppsCount() async -> Int {
        let apps = await self.fetchIntuneApps()
        let installedApps = apps.filter { app in
            guard
                let complianceStateMessage = app["ComplianceStateMessage"] as? [String: Any],
                let enforcementStateMessage = app["EnforcementStateMessage"] as? [String: Any],
                let applicability = complianceStateMessage["Applicability"] as? Int,
                let enforcementState = enforcementStateMessage["EnforcementState"] as? Int
            else {
                return false // Skip this app if data is missing
            }

            // Apply the filtering condition
            return applicability != 0 || enforcementState == 1000
        }
        return installedApps.count
    }
    
    func getPendingUpdatesCount() async -> Int {
        let apps = await self.fetchIntuneApps()
        let pendingUpdates = apps.filter { app in
            guard
                let complianceStateMessage = app["ComplianceStateMessage"] as? [String: Any],
                let enforcementStateMessage = app["EnforcementStateMessage"] as? [String: Any],
                let applicability = complianceStateMessage["Applicability"] as? Int,
                let enforcementState = enforcementStateMessage["EnforcementState"] as? Int
            else {
                return false // Skip this app if data is missing
            }

            // Apply the filtering condition
            return applicability == 0 && enforcementState != 1000
        }
        return pendingUpdates.count
    }
    
    func getPendingUpdatesList() async -> [PendingIntuneUpdate] {
        let apps = await self.fetchIntuneApps()
        var showInfoIcon: Bool = false
        
        // Filter apps to include only those matching the pending condition
        let pendingApps = apps.filter { app in
            guard
                let complianceStateMessage = app["ComplianceStateMessage"] as? [String: Any],
                let enforcementStateMessage = app["EnforcementStateMessage"] as? [String: Any],
                let applicability = complianceStateMessage["Applicability"] as? Int,
                let enforcementState = enforcementStateMessage["EnforcementState"] as? Int
            else {
                return false // Skip if any required data is missing
            }
            
            // Include apps where Applicability == 0 and EnforcementState != 1000
            return applicability == 0 && enforcementState != 1000
        }
        
        // Map filtered apps to PendingIntuneUpdate objects
        let pendingUpdates = pendingApps.compactMap { app -> PendingIntuneUpdate? in
            guard
                let name = app["ApplicationName"] as? String
                //let version = complianceStateMessage["ProductVersion"] as? String,
            else {
                return nil // Skip if any required fields are missing
            }
            
            
            let policy = app["Policy"] as? [String: Any] ?? [:]
            let appInfos = policy["AppInfos"] as? [[String: Any]] ?? []
            let version = appInfos.first?["AppVersion"] as? String ?? ""
            let errorDetails = app["ErrorDetails"] as? String ?? ""
            
            Logger.shared.logDebug(String(describing: app))
            
            // Use version in the pending reason
            let pendingReason = errorDetails
            if !errorDetails.isEmpty {
                showInfoIcon = true
            }
            return PendingIntuneUpdate(id: UUID(), name: name, pendingReason: pendingReason, showInfoIcon: showInfoIcon, version: version)
        }
        
        return pendingUpdates
    }
    
    func getInstalledAppsList() async -> [[String: Any]]? {
        let apps = await self.fetchIntuneApps()
        
        let installedApps = apps.filter { app in
            guard
                let complianceStateMessage = app["ComplianceStateMessage"] as? [String: Any],
                let enforcementStateMessage = app["EnforcementStateMessage"] as? [String: Any],
                let applicability = complianceStateMessage["Applicability"] as? Int,
                let enforcementState = enforcementStateMessage["EnforcementState"] as? Int
            else {
                return false // Skip this app if data is missing
            }

            // Apply the filtering condition
            return applicability != 0 || enforcementState == 1000
        }
        return installedApps
    }

    // Parse a row into a dictionary
    private func parseRow(statement: OpaquePointer, columnIndex: Int) -> [String: Any]? {
        guard let policyResultJsonCStr = sqlite3_column_text(statement, Int32(columnIndex)) else {
            Logger.shared.logError("Failed to fetch column data at index \(columnIndex)")
            return nil
        }

        let policyResultJson = String(cString: UnsafeRawPointer(policyResultJsonCStr).assumingMemoryBound(to: CChar.self))

        return parseJsonToDictionary(policyResultJson)
    }

    // Parse JSON string into a dictionary
    private func parseJsonToDictionary(_ json: String) -> [String: Any]? {
        guard let jsonData = json.data(using: .utf8) else {
            Logger.shared.logError("Invalid JSON string: \(json)")
            return nil
        }
        do {
            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                return jsonObject
            } else {
                Logger.shared.logError("JSON is not a valid dictionary: \(json)")
                return nil
            }
        } catch {
            Logger.shared.logError("Failed to parse JSON: \(error.localizedDescription)")
            return nil
        }
    }
}

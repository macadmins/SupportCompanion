//
//  SystemProfilerApps.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation
import Combine

class SystemProfilerApplications {
    // Function to get installed apps
    func getInstalledApps() async -> [[String: Any]] {
        var appsJson = ""
        Logger.shared.logDebug("Getting installed applications")
        
        // Run the command to fetch installed apps in JSON format
        do {
            appsJson = try await ExecutionService.executeCommandToFile("/usr/sbin/system_profiler", with: ["SPApplicationsDataType", "-json"])
        } catch {
            Logger.shared.logError("Failed to get installed apps: \(error.localizedDescription)")
        }

        // Parse the JSON response
        let data = appsJson.data(using: .utf8)!
        do {
            if let apps = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                var appsList = apps["SPApplicationsDataType"] as? [[String: Any]] {
                appsList = appsList.filter { app in
                    let path = app["path"] as? String ?? ""
                    return !path.isEmpty && path.starts(with: "/Applications")
                }
                return appsList
            }
        } catch {
            Logger.shared.logError("Failed to parse installed apps: \(error.localizedDescription)")
        }
        
        return []
    }
}

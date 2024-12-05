//
//  IntuneApps.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation
import SQLite3

class IntuneApps {
    private let installedMessages = [
        "App with specific bundle ID is installed on the device", 
        "Found bundle path URL for PKG app", 
        "Found receipt for PKG app"
    ]

    func getInstalledAppsListFromLog() async -> [[String: Any]] {
        let logParser = IntuneLogParser()
        let apps = await logParser.parseLogFiles()

        let installedApps = apps.filter { app in 
            guard 
                let info = app["Info"] as? [String: Any],
                let message = info["Message"] as? String
            else { return false }
            return installedMessages.contains(message)
        }

        return installedApps
    }

    func getInstalledAppsCountFromLog() async -> Int {
        let logParser = IntuneLogParser()
        let apps = await logParser.parseLogFiles()

        let installedApps = apps.filter { app in 
            guard 
                let info = app["Info"] as? [String: Any],
                let message = info["Message"] as? String
            else { return false }
            return installedMessages.contains(message)
        }

        return installedApps.count
    }

    func getPendingUpdatesCountFromLog() async -> Int {
        let logParser = IntuneLogParser()
        let apps = await logParser.parseLogFiles()

        let pendingUpdates = apps.filter { app in 
            guard 
                let info = app["Info"] as? [String: Any],
                let message = info["Message"] as? String
            else { return false }
            return !installedMessages.contains(message)
        }

        return pendingUpdates.count
    }

    func getPendingUpdatesListFromLog() async -> [PendingIntuneUpdate] {
        let logParser = IntuneLogParser()
        let apps = await logParser.parseLogFiles()
        var showInfoIcon: Bool = false

        let pendingApps = apps.filter { app in 
            guard 
                let info = app["Info"] as? [String: Any],
                let message = info["Message"] as? String
            else { return false }
            return !installedMessages.contains(message)
        }

        let pendingUpdates = pendingApps.compactMap { app -> PendingIntuneUpdate? in
            guard 
                let info = app["Info"] as? [String: Any],
                let appName = info["AppName"] as? String
            else { return nil }

            let version = info["Version"] as? String ?? ""
            let error = info["Message"] as? String ?? ""

            let pendingReason = error
            if !error.isEmpty {
                showInfoIcon = true
            }
            return PendingIntuneUpdate(id: UUID(), name: appName, pendingReason: pendingReason, showInfoIcon: showInfoIcon, version: version)
        }

        return pendingUpdates
    }
}

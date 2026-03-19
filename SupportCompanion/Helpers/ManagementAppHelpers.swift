//
//  ManagementAppHelpers.swift
//  SupportCompanion
//

import Foundation

extension ActionHelpers {
    static func openSystemUpdates() {
        Task {
            do {
                Logger.shared.logDebug("Opening system updates")
                try await _ = ExecutionService.executeCommand("open", with: [Constants.Panels.softwareUpdates])
            } catch {
                Logger.shared.logError("Failed to open system updates: \(error)")
            }
        }
    }

    static func openBackgroundSecurityImprovements() {
        Task {
            do {
                Logger.shared.logDebug("Opening background security improvements")
                try await _ = ExecutionService.executeCommand("open", with: [Constants.Panels.backgroundSecurityImprovements])
            } catch {
                Logger.shared.logError("Failed to open background security improvements: \(error)")
            }
        }
    }

    static func openManagementApp(appURL: String) {
        Task {
            do {
                Logger.shared.logDebug("Opening Managed Software Center")
                try await _ = ExecutionService.executeCommand("open", with: [appURL])
            } catch {
                Logger.shared.logError("Failed to open Managed Software Center: \(error)")
            }
        }
    }

    static func openSupportPage(url: String) {
        Task {
            do {
                Logger.shared.logDebug("Opening support page \(url)")
                try await _ = ExecutionService.executeCommand("open", with: [url])
            } catch {
                Logger.shared.logError("Failed to open support page \(url): \(error)")
            }
        }
    }

    static func openUserPanel() {
        Task {
            do {
                Logger.shared.logDebug("Opening Users & Groups")
                try await _ = ExecutionService.executeCommand("open", with: [Constants.Panels.users])
            } catch {
                Logger.shared.logError("Failed to open Users & Groups: \(error)")
            }
        }
    }
}

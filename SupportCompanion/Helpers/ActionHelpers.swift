//
//  ActionHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-17.
//

import Foundation
import AppKit
import Network

struct ActionHelpers {
    
    static private let tempArchivePath = Constants.Paths.tempArchivePath
    
    enum OperationResult {
        case success(String)
        case failure(Error)
        case info(String)
    }
    
    enum ConnectionError: LocalizedError {
        case noInternetConnection

        var errorDescription: String? {
            switch self {
            case .noInternetConnection:
                return Constants.Errors.noInternetConnection
            }
        }
    }
    
    enum SSOError: LocalizedError {
        case invalidRealm
        case commandFailed

        var errorDescription: String? {
            switch self {
            case .invalidRealm:
                return Constants.Errors.invalidRealmSSO
            case .commandFailed:
                return Constants.Errors.commandFailedSSO
            }
        }
    }
    
    static func handleResult(
        operationName: String,
        result: OperationResult,
        successMessage: String,
        updateToast: @escaping (ToastConfig) -> Void
    ) {
        DispatchQueue.main.async {
            let toastConfig: ToastConfig

            switch result {
            case .success(let executionResult):
                if executionResult.contains("No matching processes") {
                    toastConfig = .init(
                        isShowing: true,
                        type: .error(.red),
                        title: operationName,
                        subTitle: "\(operationName) was not running."
                    )
                } else {
                    toastConfig = .init(
                        isShowing: true,
                        type: .complete(.green),
                        title: operationName,
                        subTitle: successMessage
                    )
                }

            case .failure(let error):
                toastConfig = .init(
                    isShowing: true,
                    type: .error(.red),
                    title: operationName,
                    subTitle: error.localizedDescription
                )

            case .info(let info):
                toastConfig = .init(
                    isShowing: true,
                    type: .systemImage("info.circle.fill", .yellow),
                    title: operationName,
                    subTitle: info
                )
            }

            updateToast(toastConfig)
        }
    }

    static func openSystemUpdates() {
        Task{
            do {
                Logger.shared.logDebug("Opening system updates")
                try await _ = ExecutionService.executeCommand("open", with: [Constants.Panels.softwareUpdates])
            }
            catch {
                Logger.shared.logError("Failed to open system updates: \(error)")
            }
        }
    }
    
    static func openManagementApp(appURL: String) {
        Task {
            do {
                Logger.shared.logDebug("Opening Managed Software Center")
                try await _ = ExecutionService.executeCommand("open", with: [appURL])
            }
            catch {
                Logger.shared.logError("Failed to open Managed Software Center: \(error)")
            }
        }
    }
    
    static func openSupportPage(url: String) {
        Task {
            do {
                Logger.shared.logDebug("Opening support page \(url)")
                try await _ = ExecutionService.executeCommand("open", with: [url])
            }
            catch {
                Logger.shared.logError("Failed to open support page \(url): \(error)")
            }
        }
    }
    
    static func reboot(completion: @escaping (OperationResult) -> Void) async {
        cancelShutdown()
        
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay

        // Show modal or trigger UI update
        DispatchQueue.main.async {
            Logger.shared.logDebug("Preparing to reboot")
            completion(.info("")) // Show modal or toast here
        }
        
        // Execute the reboot command directly
        do {
            _ = try await ExecutionService.executeCommandPrivileged("shutdown", arguments: ["-r", "+1"])
            Logger.shared.logDebug("Reboot command executed")
        } catch {
            if (error as NSError).domain == NSCocoaErrorDomain && (error as NSError).code == NSUserCancelledError {
                Logger.shared.logDebug("Reboot task was canceled")
                completion(.info("Reboot operation canceled by user"))
            } else {
                Logger.shared.logError("Failed to reboot: \(error)")
                completion(.failure(error))
            }
        }
    }
    
    static func cancelShutdown() {
        do {
            Task {
                _ = try await ExecutionService.executeCommandPrivileged("killall", arguments: ["shutdown"])
                Logger.shared.logDebug("Cancel reboot command executed")
            }
        }
    }
    
    static func getSystemUpdateStatus(sendNotification: Bool = false) async -> Result<(Int, [String]), Error> {
        let notificationService = NotificationService(appState: AppStateManager.shared)
        let appState = AppStateManager.shared
        
        do {
            let executionResult = try await ExecutionService.executeCommand("/usr/sbin/softwareupdate", with: ["-l"])
            let lines = executionResult.split(whereSeparator: \.isNewline)
            
            var updateCount = 0
            var updates: [String] = []
            
            for line in lines {
                if line.contains("*") {
                    updateCount += 1
                    updates.append(String(line))
                }
            }
            
            if updateCount > 0 && sendNotification {
                notificationService.sendNotification(
                    message: appState.preferences.softwareUpdateNotificationMessage,
                    buttonText: appState.preferences.softwareUpdateNotificationButtonText,
                    command: appState.preferences.softwareUpdateNotificationCommand,
                    notificationType: .softwareUpdate
                )
            }
            
            return .success((updateCount, updates))
        } catch {
            return .failure(error)
        }
    }
    
    static func gatherLogs(preferences: Preferences, completion: @escaping (OperationResult) -> Void) {
        let command = buildZipCommand(for: preferences.logFolders)
        Logger.shared.logDebug("Gathering logs with command: \(command)")
        Task {
            do {
                _ = try await ExecutionService.executeCommand("/bin/sh", with: ["-c", command])
                Logger.shared.logDebug("Zip command executed successfully")
                
                guard let selectedURL = await promptSaveLocation() else {
                    completion(.info(Constants.ToastMessages.InfoMessages.gatherLogsInfo))
                    return
                }
                
                try saveArchive(to: selectedURL)
                completion(.success(selectedURL.path))
            } catch {
                Logger.shared.logError("Error gathering logs: \(error)")
                completion(.failure(error))
            }
        }
    }

    static private func buildZipCommand(for logFolders: [String]) -> String {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: tempArchivePath) {
            _ = try? fileManager.removeItem(at: URL(fileURLWithPath: tempArchivePath))
        }
        var command = "/usr/bin/zip -r \(tempArchivePath)"
        logFolders.forEach { command += " '\($0)'" }
        return command
    }

    static private func saveArchive(to location: URL) throws {
        let fileManager = FileManager.default
        
        if fileManager.fileExists(atPath: location.path) {
            try fileManager.removeItem(at: location)
        }
        
        try fileManager.copyItem(at: URL(fileURLWithPath: tempArchivePath), to: location)
    }
    
    @MainActor
    static private func promptSaveLocation() async -> URL? {
        Logger.shared.logDebug("Prompting user to save logs")
        let savePanel = NSSavePanel()
        savePanel.title = Constants.Titles.saveLogs
        savePanel.nameFieldStringValue = "supportcompanion_logs.zip"

        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }

    static func restartIntuneAgent(completion: @escaping (OperationResult) -> Void) {
        Task {
            do {
                let executionResult = try await ExecutionService.executeCommandPrivileged(
                    "killall",
                    arguments: ["IntuneMdmAgent"]
                )
                DispatchQueue.main.async {
                    completion(.success(executionResult))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    static func openChangePassword(preferences: Preferences, completion: @escaping (OperationResult) -> Void) async {
        guard await checkForInternetConnection() else {
            completion(.failure(ConnectionError.noInternetConnection))
            return
        }

        if preferences.changePasswordMode == "url" {
            await openURL(preferences.changePasswordUrl, completion: completion)
        } else if preferences.changePasswordMode == "SSOExtension" {
            await handleSSOExtension(completion: completion)
        } else {
            await openUserPanel()
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

    static private func openURL(_ url: String, completion: @escaping (OperationResult) -> Void) async {
        do {
            _ = try await ExecutionService.executeCommand("open", with: [url])
            Logger.shared.logDebug("URL opened: \(url)")
        } catch {
            completion(.failure(error))
        }
    }

    static private func handleSSOExtension(completion: @escaping (OperationResult) -> Void) async {
        do {
            let realmInfo = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["-l", "--json"])
            guard let realmName = parseRealm(from: realmInfo) else {
                throw SSOError.invalidRealm
            }

            let reachable = try await ping(host: realmName)
            if reachable {
                _ = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["-c", realmName])
                Logger.shared.logDebug("Password change initiated for realm: \(realmName)")
            } else {
                let infoMessage = String(format: Constants.ToastMessages.InfoMessages.changePasswordSSOEInfo, realmName)
                completion(.info(infoMessage))
            }
        } catch {
            completion(.failure(error))
        }
    }

    static private func parseRealm(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let realms = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return realms.first
    }
    
    static func checkForInternetConnection() async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")
        var isConnected = false

        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
        }

        monitor.start(queue: queue)
        try? await Task.sleep(nanoseconds: 500_000_000) // Wait for 0.5 seconds
        monitor.cancel()

        return isConnected
    }
    
    static private func ping(host: String) async throws -> Bool {
        let process = Process()
        let pipe = Pipe()
        
        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", host] // Send 1 ping
        
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }
}

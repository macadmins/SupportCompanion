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
                    message: appState.preferences.notifications.softwareUpdateNotificationMessage,
                    buttonText: appState.preferences.notifications.softwareUpdateNotificationButtonText,
                    command: appState.preferences.notifications.softwareUpdateNotificationCommand,
                    notificationType: .softwareUpdate
                )
            }

            return .success((updateCount, updates))
        } catch {
            return .failure(error)
        }
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
            openUserPanel()
        }
    }

    static func checkForInternetConnection() async -> Bool {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "NetworkMonitor")

        monitor.start(queue: queue)
        try? await Task.sleep(nanoseconds: 500_000_000)
        let isConnected = monitor.currentPath.status == .satisfied
        monitor.cancel()

        return isConnected
    }

    private static func openURL(_ url: String, completion: @escaping (OperationResult) -> Void) async {
        do {
            _ = try await ExecutionService.executeCommand("open", with: [url])
            Logger.shared.logDebug("URL opened: \(url)")
        } catch {
            completion(.failure(error))
        }
    }

    private static func handleSSOExtension(completion: @escaping (OperationResult) -> Void) async {
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

    private static func parseRealm(from json: String) -> String? {
        guard let data = json.data(using: .utf8),
              let realms = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return realms.first
    }

    private static func ping(host: String) async throws -> Bool {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/sbin/ping")
        process.arguments = ["-c", "1", host]

        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        return process.terminationStatus == 0
    }
}

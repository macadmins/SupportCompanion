//
//  RebootHelpers.swift
//  SupportCompanion
//

import Foundation

extension ActionHelpers {
    static func reboot(completion: @escaping (OperationResult) -> Void) async {
        cancelShutdown()

        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay

        Task { @MainActor in
            Logger.shared.logDebug("Preparing to reboot")
            completion(.info(""))
        }

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
        Task {
            _ = try? await ExecutionService.executeCommandPrivileged("killall", arguments: ["shutdown"])
            Logger.shared.logDebug("Cancel reboot command executed")
        }
    }
}

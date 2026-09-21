//
//  ExecutionService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - ExecutionService

/// Runs commands, either here as the logged-in user or, for the privileged operations, by asking the
/// helper to perform a named one.
///
/// The helper no longer takes a command to run. Each privileged call below names an operation the helper
/// implements, and the helper decides what that operation executes and whether policy allows it, so code
/// running in this process cannot turn the helper into a way to run something as root.
enum ExecutionService {

    // MARK: Unprivileged

    /// Execute a command with arguments as the logged-in user.
    static func executeCommand(_ command: String, with arguments: [String] = []) async throws -> String {
        Logger.shared.logDebug("Executing command \(command) with arguments \(arguments))")
        return try await ProcessRunner.runCommand(command, with: arguments)
    }

    /// Execute a shell command as the logged-in user.
    static func executeShellCommand(_ rawCommand: String) async throws -> String {
        guard !rawCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.shared.logDebug("Command must not be null or whitespace")
            throw NSError(domain: "ExecutionServiceError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Command must not be null or whitespace"
            ])
        }

        // The command is passed to /bin/sh as a single argument, so it must not be escaped.
        // Escaping quotes here would corrupt any command that contains them.
        return try await executeCommand("/bin/sh", with: ["-c", rawCommand])
    }

    // MARK: Actions

    /// Run an administrator-defined action.
    ///
    /// A privileged action is only named to the helper; the helper looks the command up in the
    /// administrator-managed preferences itself, so what runs as root is never taken from this process.
    static func runAction(_ action: Action) async throws -> String {
        if action.isPrivileged ?? false {
            return try await HelperRemoteProvider.remote().runPrivilegedAction(named: action.name)
        }

        return try await executeShellCommand(action.command)
    }

    // MARK: Elevation

    static func elevate(reason: String) async throws -> String {
        try await HelperRemoteProvider.remote().elevate(reason: reason)
    }

    static func demote() async throws -> String {
        try await HelperRemoteProvider.remote().demote()
    }

    /// Seconds until the helper takes administrator rights back, or 0 when no elevation is active.
    static func elevationTimeRemaining() async throws -> Double {
        try await HelperRemoteProvider.remote().elevationTimeRemaining()
    }

    // MARK: Jamf

    static func jamfPatch(id: String) async throws -> String {
        try await HelperRemoteProvider.remote().jamfPatch(id: id)
    }

    static func jamfSelfServicePatch(id: String, userId: String?) async throws -> String {
        try await HelperRemoteProvider.remote().jamfSelfServicePatch(id: id, userId: userId)
    }

    static func jamfRecon() async throws -> String {
        try await HelperRemoteProvider.remote().jamfRecon()
    }

    static func jamfLog(kind: JamfLogKind, hours: Int) async throws -> String {
        try await HelperRemoteProvider.remote().jamfLog(kind: kind.rawValue, hours: hours)
    }

    /// The fixed Jamf log queries the helper knows how to run.
    enum JamfLogKind: String {
        case checkIn
        case inventory
    }

    // MARK: Device management

    static func restartIntuneAgent() async throws -> String {
        try await HelperRemoteProvider.remote().restartIntuneAgent()
    }

    static func mdmEnrollmentDate() async throws -> String {
        try await HelperRemoteProvider.remote().mdmEnrollmentDate()
    }

    // MARK: System

    static func reboot() async throws -> String {
        try await HelperRemoteProvider.remote().reboot()
    }

    static func cancelReboot() async throws -> String {
        try await HelperRemoteProvider.remote().cancelReboot()
    }

    static func setIPConfigVerbose(_ enabled: Bool) async throws -> String {
        try await HelperRemoteProvider.remote().setIPConfigVerbose(enabled)
    }
}

//
//  ExecutionService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - ExecutionService

/// Execute a script.
enum ExecutionService {

    // MARK: Execute Script
    static func executeScript(at path: String) async throws -> String {
        try await HelperRemoteProvider.remote().executeScript(at: path)
    }

    // MARK: Execute Command
    /// Execute a command with arguments.
    static func executeCommandPrivileged(_ command: String, arguments: [String]) async throws -> String {
        try await HelperRemoteProvider.remote().executeCommand(command, with: arguments)
    }
    
    static func executeCommand(_ command: String, with arguments: [String] = []) async throws -> String {
        Logger.shared.logDebug("Executing command \(command) with arguments \(arguments))")
        return try await ProcessRunner.runCommand(command, with: arguments)
    }
    
    static func executeShellCommand(_ rawCommand: String, isPrivileged: Bool? = false) async throws -> String {
        guard !rawCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.shared.logDebug("Command must not be null or whitespace")
            throw NSError(domain: "ExecutionServiceError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Command must not be null or whitespace"
            ])
        }

        // The command is passed to /bin/sh as a single argument, so it must not be escaped.
        // Escaping quotes here would corrupt any command that contains them.
        let arguments = ["-c", rawCommand]
        
        // check if privileged execution is requested and execute accordingly
        if let isPrivileged, isPrivileged {
            return try await executeCommandPrivileged("/bin/sh", arguments: arguments)
        }
        
        // Execute using the existing method
        return try await executeCommand("/bin/sh", with: arguments)
    }

}

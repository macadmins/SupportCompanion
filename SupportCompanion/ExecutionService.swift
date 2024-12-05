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

    // MARK: Constants
    static let programURL = URL(fileURLWithPath: "/usr/bin/env")

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
        let process = Process()
        process.executableURL = programURL
        process.arguments = [command] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()
    
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ExecutionServiceError",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: "Command '\(command)' failed with status \(process.terminationStatus): \(errorOutput)"
                ]
            )
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }
    
    static func executeCommandToFile(_ command: String, with arguments: [String] = []) async throws -> String {
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("process_output.json")
        // Create the file if it doesn't exist
        FileManager.default.createFile(atPath: tempURL.path, contents: nil, attributes: nil)
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = try FileHandle(forWritingTo: tempURL)

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            throw NSError(
                domain: "ExecutionServiceError",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Command failed with status \(process.terminationStatus)"]
            )
        }

        let data = try Data(contentsOf: tempURL)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    static func executeShellCommand(_ rawCommand: String, isPrivileged: Bool? = false) async throws -> String {
        guard !rawCommand.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Logger.shared.logDebug("Command must not be null or whitespace")
            throw NSError(domain: "ExecutionServiceError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Command must not be null or whitespace"
            ])
        }

        // Escape single quotes within the command
        let escapedCommand = rawCommand.replacingOccurrences(of: "'", with: "'\\''")

        // Pass the escaped command directly to /bin/sh -c
        let arguments = ["-c", escapedCommand]
        
        if isPrivileged! {
            return try await executeCommandPrivileged("/bin/sh", arguments: arguments)
        }
        // Execute using the existing method
        return try await executeCommand("/bin/sh", with: arguments)
    }
}

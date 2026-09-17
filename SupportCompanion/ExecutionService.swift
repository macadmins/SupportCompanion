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
        Logger.shared.logDebug("Executing command \(command) with arguments \(arguments))")

        let result = try await runProcess(executableURL: programURL, arguments: [command] + arguments)

        if result.status != 0 {
            let errorOutput = String(data: result.error, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "ExecutionServiceError",
                code: Int(result.status),
                userInfo: [
                    NSLocalizedDescriptionKey: "Command '\(command)' failed with status \(result.status): \(errorOutput)"
                ]
            )
        }

        return String(data: result.output, encoding: .utf8) ?? ""
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

    // MARK: Process running

    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    /// Runs a process and collects its output.
    ///
    /// The pipes are drained while the process runs. Waiting for exit before reading deadlocks as soon
    /// as a command writes more than the pipe buffer (~64KB): the child blocks on write and never exits.
    /// The blocking work happens on a GCD thread rather than the Swift concurrency thread pool.
    private static func runProcess(executableURL: URL, arguments: [String]) async throws -> (status: Int32, output: Data, error: Data) {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }

                let output = DataBox()
                let errorOutput = DataBox()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    output.data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    errorOutput.data = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                group.wait()
                process.waitUntilExit()

                continuation.resume(returning: (process.terminationStatus, output.data, errorOutput.data))
            }
        }
    }
}

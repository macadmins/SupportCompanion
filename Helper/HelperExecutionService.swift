//
//  HelperExecutionService.swift
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

    // MARK: Execute

    /// Execute the script at the provided URL.
    static func executeScript(at path: String) async throws -> String {
        let process = Process()
        process.executableURL = programURL
        process.arguments = [path]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        try process.run()

        return try await Task {
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()

            guard let output = String(data: outputData, encoding: .utf8) else {
                throw SupportCompanionErrors.invalidStringConversion
            }

            return output
        }
        .value
    }
    
    static func executeCommand(_ command: String, with arguments: [String] = []) async throws -> String {
        let result = try await runProcess(executableURL: programURL, arguments: [command] + arguments)

        // Capture and check for errors
        if result.status != 0 {
            let errorOutput = String(data: result.error, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ExecutionServiceError", code: Int(result.status), userInfo: [NSLocalizedDescriptionKey: errorOutput])
        }

        return String(data: result.output, encoding: .utf8) ?? ""
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

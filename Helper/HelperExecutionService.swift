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
        let process = Process()
        process.executableURL = programURL
        process.arguments = [command] + arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        // Capture and check for errors
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "ExecutionServiceError", code: Int(process.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput])
        }

        // Capture and return the output
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}

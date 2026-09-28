//
//  ProcessRunner.swift
//  SupportCompanion
//
//  Shared by the app and the privileged helper.
//

import Foundation

enum ProcessRunner {

    private final class DataBox: @unchecked Sendable {
        var data = Data()
    }

    /// Runs `command` through `/usr/bin/env` and returns its standard output.
    /// Throws when the command exits with a non-zero status, including its standard error.
    static func runCommand(_ command: String, with arguments: [String] = []) async throws -> String {
        let result = try await run(executableURL: URL(fileURLWithPath: "/usr/bin/env"), arguments: [command] + arguments)

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

    /// Runs a process and collects its output.
    ///
    /// The pipes are drained while the process runs. Waiting for exit before reading deadlocks as soon
    /// as a command writes more than the pipe buffer (~64KB): the child blocks on write and never exits.
    /// The blocking work happens on a GCD thread rather than the Swift concurrency thread pool.
    static func run(executableURL: URL, arguments: [String]) async throws -> (status: Int32, output: Data, error: Data) {
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

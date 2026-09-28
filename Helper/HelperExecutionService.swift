//
//  HelperExecutionService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - ExecutionService

/// Runs the commands behind the helper's operations.
///
/// Nothing here is reachable from a client directly. Every caller is a named operation in `HelperService`
/// that supplies its own executable path, so the set of programs the helper can run as root is fixed at
/// compile time — with the single exception of `shell(_:)`, which runs an administrator-defined action.
enum ExecutionService {

    /// Run an executable by absolute path.
    ///
    /// Absolute paths only: the helper's `PATH` comes from launchd, and a root daemon has no business
    /// resolving program names through it.
    static func run(_ executable: String, _ arguments: [String] = []) async throws -> String {
        guard executable.hasPrefix("/") else {
            throw SupportCompanionErrors.helperConnection("Refusing to run '\(executable)': not an absolute path")
        }

        let result = try await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: executable),
            arguments: arguments
        )

        guard result.status == 0 else {
            let errorOutput = String(data: result.error, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "HelperExecutionError",
                code: Int(result.status),
                userInfo: [
                    NSLocalizedDescriptionKey: "'\(executable)' failed with status \(result.status): \(errorOutput)"
                ]
            )
        }

        return String(data: result.output, encoding: .utf8) ?? ""
    }

    /// Run an administrator-defined action command through `/bin/sh`.
    ///
    /// The command always comes from `HelperPreferences`, never from the connection.
    static func shell(_ command: String) async throws -> String {
        try await run("/bin/sh", ["-c", command])
    }
}

//
//  Logger.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import os

final class Logger {
    static let shared = Logger()

    // Unified Logging
    private var logger: OSLog

    // File logging configuration
    private var fileLoggingEnabled = true
    private var debugEnabled = false
    private var logDirectoryURL: URL
    private var logFileURL: URL
    private var maxFileSizeBytes: Int = 5 * 1024 * 1024 // 5 MB
    private var maxRotatedFiles: Int = 5

    // File I/O isolation
    private let fileQueue = DispatchQueue(label: "com.github.macadmins.SupportCompanion.LoggerFileQueue")

    private init() {
        // OSLog setup
        let subsystem = Bundle.main.bundleIdentifier ?? "com.github.macadmins.SupportCompanion"
        let category = "SupportCompanion"
        logger = OSLog(subsystem: subsystem, category: category)

        // Default file log path: /Library/Logs/SupportCompanion/SupportCompanion.log
        // If you prefer per-user logs, change to .userDomainMask and ~/Library/Logs path.
        let base = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Logs/SupportCompanion", isDirectory: true)
        self.logDirectoryURL = dir
        self.logFileURL = dir.appendingPathComponent("SupportCompanion.log")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Configuration

    func configure(subsystem: String, category: String) {
        logger = OSLog(subsystem: subsystem, category: category)
    }
	
	func setFileDebugLogging(_ enabled: Bool) {
		fileQueue.sync { self.debugEnabled = enabled }
	}

    // MARK: - Public logging API

    func logInfo(_ message: String) {
        os_log("%{public}@", log: logger, type: .info, message)
        writeToFile(level: "INFO", message: message)
    }

    func logError(_ message: String) {
        os_log("%{public}@", log: logger, type: .error, message)
        writeToFile(level: "ERROR", message: message)
    }

    func logDebug(_ message: String) {
        os_log("%{public}@", log: logger, type: .debug, message)
        guard debugEnabled else { return }
        writeToFile(level: "DEBUG", message: message)
    }

    // Optional: add warnings for parity with your other enum
    func logWarning(_ message: String) {
        os_log("%{public}@", log: logger, type: .default, message)
        writeToFile(level: "WARNING", message: message)
    }

    // MARK: - File logging core

    private func writeToFile(level: String, message: String) {
        guard fileLoggingEnabled else { return }

        let ts = ISO8601DateFormatter().string(from: Date())
        let line = "[\(ts)] [\(level)] \(message)\n"

        fileQueue.async {
            guard let data = line.data(using: .utf8) else { return }

            // Ensure directory exists
            if !FileManager.default.fileExists(atPath: self.logDirectoryURL.path) {
                try? FileManager.default.createDirectory(at: self.logDirectoryURL, withIntermediateDirectories: true)
            }

            // Ensure file exists
            if !FileManager.default.fileExists(atPath: self.logFileURL.path) {
                FileManager.default.createFile(atPath: self.logFileURL.path, contents: nil)
            }

            // Append
            if let handle = try? FileHandle(forWritingTo: self.logFileURL) {
                do {
                    try handle.seekToEnd()
                    try handle.write(contentsOf: data)
                } catch {
                    // Swallow file write errors to avoid recursion via logging
                }
                try? handle.close()
            }

            // Rotate if needed
            self.rotateIfNeeded()
        }
    }

    private func rotateIfNeeded() {
        guard
            let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
            let size = attrs[.size] as? NSNumber,
            size.intValue > maxFileSizeBytes
        else { return }

        // Shift old logs: .log.(n-1) -> .log.n
        let baseName = logFileURL.deletingPathExtension().lastPathComponent
        let ext = logFileURL.pathExtension.isEmpty ? "log" : logFileURL.pathExtension

        func rotatedURL(_ index: Int) -> URL {
            logDirectoryURL.appendingPathComponent("\(baseName).\(ext).\(index)")
        }

        for i in stride(from: maxRotatedFiles - 1, through: 1, by: -1) {
            let src = rotatedURL(i)
            let dst = rotatedURL(i + 1)
            if FileManager.default.fileExists(atPath: src.path) {
                try? FileManager.default.removeItem(at: dst)
                try? FileManager.default.moveItem(at: src, to: dst)
            }
        }

        let first = rotatedURL(1)
        try? FileManager.default.removeItem(at: first)
        try? FileManager.default.moveItem(at: logFileURL, to: first)

        // Create a fresh file
        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    }
}

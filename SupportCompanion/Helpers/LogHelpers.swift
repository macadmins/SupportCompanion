//
//  LogHelpers.swift
//  SupportCompanion
//

import Foundation
import AppKit

extension ActionHelpers {
	@MainActor static func gatherLogs(preferences: Preferences, completion: @escaping (OperationResult) -> Void) {
        let command = buildZipCommand(for: preferences.logFolders, excluding: preferences.excludedLogFolders)
        Logger.shared.logDebug("Gathering logs with command: \(command)")
        Task {
            do {
                _ = try await ExecutionService.executeCommand("/bin/sh", with: ["-c", command])
                Logger.shared.logDebug("Zip command executed successfully")

                guard let selectedURL = await promptSaveLocation() else {
                    completion(.info(Constants.ToastMessages.InfoMessages.gatherLogsInfo))
                    return
                }

                try saveArchive(to: selectedURL)
                completion(.success(selectedURL.path))
            } catch {
                Logger.shared.logError("Error gathering logs: \(error)")
                completion(.failure(error))
            }
        }
    }

    private static func buildZipCommand(for logFolders: [String], excluding excludedLogFolders: [String]) -> String {
        let fileManager = FileManager.default
        let archivePath = Constants.Paths.tempArchivePath
        if fileManager.fileExists(atPath: archivePath) {
            _ = try? fileManager.removeItem(at: URL(fileURLWithPath: archivePath))
        }
        var command = "/usr/bin/zip -r \(archivePath)"
        logFolders.forEach { command += " '\($0)'" }
        if !excludedLogFolders.isEmpty {
            command += " -x"
            excludedLogFolders.forEach { command += " '\($0)/*'" }
        }
        return command
    }

    private static func saveArchive(to location: URL) throws {
        let fileManager = FileManager.default
        let archivePath = Constants.Paths.tempArchivePath
        if fileManager.fileExists(atPath: location.path) {
            try fileManager.removeItem(at: location)
        }
        try fileManager.copyItem(at: URL(fileURLWithPath: archivePath), to: location)
    }

    @MainActor
    private static func promptSaveLocation() async -> URL? {
        Logger.shared.logDebug("Prompting user to save logs")
        let savePanel = NSSavePanel()
        savePanel.title = Constants.Titles.saveLogs
        savePanel.nameFieldStringValue = "supportcompanion_logs.zip"
        let response = savePanel.runModal()
        return response == .OK ? savePanel.url : nil
    }
}

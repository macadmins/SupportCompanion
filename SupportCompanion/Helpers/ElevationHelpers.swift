import LocalAuthentication
import Foundation
import SwiftUI
import Combine

func authenticateWithTouchIDOrPassword(completion: @escaping (Bool) -> Void, reason: String) {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        // Try Touch ID/Face ID
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            if success {
                // Authentication successful
                DispatchQueue.main.async {
                    completion(true)
                }
            } else {
                // Fallback to password
                authenticateWithPassword(completion: completion, reason: reason)
            }
        }
    } else {
        // Biometrics unavailable, fallback to password
        authenticateWithPassword(completion: completion, reason: reason)
    }
}

func authenticateWithPassword(completion: @escaping (Bool) -> Void, reason: String) {
    let context = LAContext()
    var error: NSError?

    // Check if deviceOwnerAuthentication (password fallback) is available
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, authError in
            DispatchQueue.main.async {
                if success {
                    // Authentication successful
                    completion(true)
                } else {
                    // Authentication failed
                    completion(false)
                }
            }
        }
    } else {
        // Device owner authentication not available
        DispatchQueue.main.async {
            completion(false)
        }
    }
}

@MainActor
func saveReasonToDisk(reason: String) {
    let fileManager = FileManager.default
    let appState = AppStateManager.shared
    
    // Get the Application Support directory
    guard let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
        Logger.shared.logError("Failed to locate Application Support directory.")
        return
    }
    
    // Create a subdirectory for your app if needed
    let appDirectory = appSupportDirectory.appendingPathComponent("SupportCompanion")
    
    do {
        // Ensure the directory exists
        if !fileManager.fileExists(atPath: appDirectory.path) {
            try fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true, attributes: nil)
        }
    } catch {
        Logger.shared.logError("Error creating app directory: \(error.localizedDescription)")
        return
    }
    
    // Define the file URL
    let fileURL = appDirectory.appendingPathComponent("ElevationReasons.json")
    
    // Debug: Log the file URL
    Logger.shared.logDebug("Saving reason to: \(fileURL.path)")

    // Get the current date
    let dateFormatter = ISO8601DateFormatter()
    let currentDate = dateFormatter.string(from: Date())

    // Create a dictionary to save
    let entry: [String: Any] = [
        "reason": reason, 
        "date": currentDate,
        "user": NSUserName(),
        "host": Host.current().localizedName ?? "Unknown",
        "serial": appState.deviceInfoManager.deviceInfo?.serialNumber ?? "Unknown",
        "severity": appState.preferences.elevation.elevationSeverity
    ]

    var existingEntries: [[String: Any]] = []

    // Read existing entries if the file exists
    if fileManager.fileExists(atPath: fileURL.path) {
        do {
            let data = try Data(contentsOf: fileURL)
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                existingEntries = json
            } else {
                Logger.shared.logError("Failed to parse JSON from file. Overwriting with new entries.")
            }
        } catch {
            Logger.shared.logError("Error reading file: \(error.localizedDescription)")
        }
    }

    // Add the new entry
    existingEntries.append(entry)

    // Save back to disk
    do {
        let data = try JSONSerialization.data(withJSONObject: existingEntries, options: [.prettyPrinted])
        try data.write(to: fileURL, options: .atomic) // Atomic ensures safe writes
        Logger.shared.logDebug("Reason saved successfully.")
    } catch {
        Logger.shared.logError("Error saving reason: \(error.localizedDescription)")
    }
}

@MainActor
func sendReasonToWebhook(reason: String) {
    let dateFormatter = ISO8601DateFormatter()
    let appState = AppStateManager.shared

    guard let webhookURL = URL(string: appState.preferences.elevation.elevationWebhookURL),
          !appState.preferences.elevation.elevationWebhookURL.isEmpty else {
        Logger.shared.logError("Invalid or empty webhook URL.")
        saveReasonToDisk(reason: reason)
        return
    }

    let payload: [String: Any] = [
        "reason": reason,
        "date": dateFormatter.string(from: Date()),
        "user": NSUserName(),
        "host": Host.current().localizedName ?? "Unknown",
        "serial": appState.deviceInfoManager.deviceInfo?.serialNumber ?? "Unknown",
        "severity": appState.preferences.elevation.elevationSeverity
    ]

    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        Logger.shared.logError("Failed to serialize elevation webhook payload.")
        saveReasonToDisk(reason: reason)
        return
    }

    var request = URLRequest(url: webhookURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData

    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            Task { @MainActor in saveReasonToDisk(reason: reason) }
            Logger.shared.logError("Failed to send reason to webhook: \(error.localizedDescription)")
            return
        }

        if let response = response as? HTTPURLResponse {
            if response.statusCode == 200 || response.statusCode == 202 {
                Logger.shared.logDebug("Reason sent to webhook successfully.")
            } else {
                Task { @MainActor in saveReasonToDisk(reason: reason) }
                Logger.shared.logError("Failed to send reason to webhook. Status code: \(response.statusCode)")
            }
        }
    }

    task.resume()
}

import LocalAuthentication
import Foundation
import SwiftUI
import Combine

func authenticateWithTouchIDOrPassword(completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    var error: NSError?

    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
        // Try Touch ID/Face ID
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Authenticate to elevate privileges") { success, authError in
            if success {
                // Authentication successful
                DispatchQueue.main.async {
                    completion(true)
                }
            } else {
                // Fallback to password
                authenticateWithPassword(completion: completion)
            }
        }
    } else {
        // Biometrics unavailable, fallback to password
        authenticateWithPassword(completion: completion)
    }
}

func authenticateWithPassword(completion: @escaping (Bool) -> Void) {
    let context = LAContext()
    var error: NSError?

    // Check if deviceOwnerAuthentication (password fallback) is available
    if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to elevate privileges") { success, authError in
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
        "severity": appState.preferences.elevationSeverity
    ]

    var existingEntries: [[String: Any]] = []

    // Read existing entries if the file exists
    if let data = try? Data(contentsOf: fileURL),
       let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: String]] {
        existingEntries = json
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

func sendReasonToWebhook(reason: String) {
    let dateFormatter = ISO8601DateFormatter()
    let appState = AppStateManager.shared

    // Define the webhook URL
    let webhookURL = URL(string: appState.preferences.elevationWebhookURL)!
    
    // Create a dictionary with the reason
    let payload: [String: Any] = [
        "reason": reason, 
        "date": dateFormatter.string(from: Date()),
        "user": NSUserName(),
        "host": Host.current().localizedName ?? "Unknown",
        "serial": appState.deviceInfoManager.deviceInfo?.serialNumber ?? "Unknown",
        "severity":appState.preferences.elevationSeverity
    ]
    
    // Serialize the dictionary to JSON
    guard let jsonData = try? JSONSerialization.data(withJSONObject: payload) else {
        print("Failed to serialize JSON.")
        return
    }
    
    // Create a POST request
    var request = URLRequest(url: webhookURL)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    // Create a URLSession task
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            saveReasonToDisk(reason: reason)
            Logger.shared.logError("Failed to send reason to webhook: \(error.localizedDescription)")
            return
        }
        
        if let response = response as? HTTPURLResponse {
            if response.statusCode == 200 || response.statusCode == 202 {
                print("Reason sent to webhook successfully.")
            } else {
                // Fallback to save to disk if webhook fails
                saveReasonToDisk(reason: reason)
                Logger.shared.logError("Failed to send reason to webhook. Status code: \(response.statusCode)")
            }
        }
    }
    
    // Start the task
    task.resume()
}

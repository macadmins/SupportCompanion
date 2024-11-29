//
//  SSOInfoHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

class SSOInfoHelpers {
    /// Fetches and parses Kerberos SSO info into a KerberosSSO model
    func fetchKerberosSSO() async throws -> KerberosSSO {
        // Fetch realm information
        let realmName = await fetchRealm()

        // Fetch Kerberos SSO info for the realm
        let kerberosSSOOutput = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["-i", realmName])
        guard let kerberosSSOData = kerberosSSOOutput.data(using: .utf8),
              let kerberosSSOInfo = try PropertyListSerialization.propertyList(from: kerberosSSOData, options: [], format: nil) as? [String: Any] else {
            throw NSError(domain: "SSOHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Kerberos SSO plist"])
        }

        // Parse data into the model
        let username = kerberosSSOInfo["user_name"] as? String ?? "Unknown"
        let realm = kerberosSSOInfo["realm"] as? String ?? "Unknown"
        let expiryDays = daysUntil(from: kerberosSSOInfo["password_expires_date"] as? String)
        let lastSSOPasswordChangeDays = daysSince(from: kerberosSSOInfo["password_changed_date"] as? String)
        let lastLocalPasswordChangeDays = daysSince(from: kerberosSSOInfo["local_password_changed_date"] as? String)

        return KerberosSSO(
            id: UUID(),
            expiryDays: expiryDays,
            lastSSOPasswordChangeDays: lastSSOPasswordChangeDays,
            realm: realm,
            lastLocalPasswordChangeDays: lastLocalPasswordChangeDays,
            username: username
        )
    }

    /// Fetches and parses Platform SSO info into a PlatformSSO model
    /// Fetches and parses Platform SSO info into a PlatformSSO model
    func fetchPlatformSSO() async throws -> PlatformSSO {
        // Fetch platform SSO information
        let platformSSOOutput = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["platform", "-s"])
        
        // Regex patterns for extracting configurations
        let deviceConfigPattern = #"Device Configuration:\s*(\{(?:[^{}]|\{[^{}]*\})*\}|\(null\))"#
        let userConfigPattern = #"User Configuration:\s*(\{(?:[^{}]|\{[^{}]*\})*\}|\(null\))"#
        
        // Extract device configuration
        let deviceConfigJSON = extractJSON(from: platformSSOOutput, pattern: deviceConfigPattern)
        guard let deviceConfigData = deviceConfigJSON?.data(using: .utf8),
              let deviceConfig = try? JSONSerialization.jsonObject(with: deviceConfigData, options: []) as? [String: Any] else {
            Logger.shared.logError("Device configuration parsing failed")
            throw NSError(domain: "SSOHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse device configuration"])
        }

        // Extract user configuration (optional, does not throw)
        let userConfigJSON = extractJSON(from: platformSSOOutput, pattern: userConfigPattern)
        let userConfig: [String: Any]
        if let userConfigData = userConfigJSON?.data(using: .utf8),
           let parsedUserConfig = try? JSONSerialization.jsonObject(with: userConfigData, options: []) as? [String: Any] {
            userConfig = parsedUserConfig
        } else {
            Logger.shared.logError("User configuration parsing failed. Using default values.")
            userConfig = [:] // Use an empty dictionary if parsing fails
        }
        
        var loginType = "Unknown"

        // Check for `loginType` in device configuration first
        if let loginTypeValue = deviceConfig["loginType"] as? String ?? userConfig["loginType"] as? String {
            // Split the string into components by spaces
            let components = loginTypeValue.split(separator: " ")

            // Iterate through each component
            for component in components {
                if component.contains("(1)") {
                    loginType = "Password"
                    break // Stop after finding the first match
                } else if component.contains("(2)") {
                    loginType = "Secure Enclave"
                    break // Stop after finding the first match
                } else if component.contains("(3)") {
                    loginType = "Smart Card"
                    break // Stop after finding the first match
                }
            }
        } else {
            loginType = "Unknown" // Default if `loginType` is not present or not a string
        }
        // Populate the PlatformSSO model
        return PlatformSSO(
            id: UUID(),
            loginFrequency: deviceConfig["loginFrequency"] as? Int ?? 0,
            loginType: loginType,
            newUserAuthorizationMode: deviceConfig["newUserAuthorizationMode"] as? String ?? "Unknown",
            registrationCompleted: deviceConfig["registrationCompleted"] as? Bool ?? false,
            sdkVersionString: deviceConfig["sdkVersionString"] as? String ?? "Unknown",
            sharedDeviceKeys: deviceConfig["sharedDeviceKeys"] as? Bool ?? false,
            userAuthorizationMode: userConfig["userAuthorizationMode"] as? String ?? "Unknown" // Mapped from user configuration
        )
    }

    // Helper to calculate days since a date
    private func daysSince(from dateString: String?) -> Int {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return -1
        }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? -1
    }

    // Helper to calculate days until a date
    private func daysUntil(from dateString: String?) -> Int {
        guard let dateString = dateString,
              let date = ISO8601DateFormatter().date(from: dateString) else {
            return -1
        }
        return Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? -1
    }

    // Helper to extract JSON using a regex pattern
    func extractJSON(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            Logger.shared.logError("Regex failed to compile for pattern: \(pattern)")
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range),
           let jsonRange = Range(match.range(at: 1), in: text) {
            return String(text[jsonRange])
        }
        return nil
    }
    
    func fetchPlatformSSOCheckOnly() async -> Bool {
        do {
            // Fetch platform SSO information
            let platformSSOOutput = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["platform", "-s"])
            // Regex pattern for extracting configurations
            let deviceConfigPattern = #"Device Configuration:\s*(\{(?:[^{}]|\{[^{}]*\})*\}|\(null\))"#

            // Extract device configuration
            let deviceConfigJSON = extractJSON(from: platformSSOOutput, pattern: deviceConfigPattern)
            guard let deviceConfigData = deviceConfigJSON?.data(using: .utf8),
                  let deviceConfig = try? JSONSerialization.jsonObject(with: deviceConfigData, options: []) as? [String: Any] else {
                Logger.shared.logError("Device configuration parsing failed")
                return false
            }
            
            // If parsing is successful, return true
            return true
            
        } catch {
            // Log error and return false
            Logger.shared.logError("Error fetching platform SSO information: \(error.localizedDescription)")
            return false
        }
    }
    
    func fetchRealm() async -> String {
        do {
            let realmOutput = try await ExecutionService.executeCommand("/usr/bin/app-sso", with: ["-l", "--json"])
            guard let realmData = realmOutput.data(using: .utf8) else {
                Logger.shared.logError("Faile to convert realm output to Data")
                return ""
            }
            
            if let realmArray = try? JSONDecoder().decode([String].self, from: realmData),
               let realmName = realmArray.first {
                return realmName
            } else {
                Logger.shared.logError("Failed to decode realm JSON")
                return ""
            }
        } catch {
            Logger.shared.logError("Failed to fetch realm: \(error.localizedDescription)")
            return ""
        }
    }
}

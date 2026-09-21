//
//  DeviceManagementHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

func getMDMEnrollmentTime() async -> String {
    // Reading the enrollment profile needs root, so the helper does it and returns just the date.
    do {
        let installDate = try await ExecutionService.mdmEnrollmentDate()
        if !installDate.isEmpty {
            Logger.shared.logDebug("MDM enrollment profile installed \(installDate)")
            return installDate
        }
        Logger.shared.logDebug("No MDM enrollment profile install date found")
    } catch {
        Logger.shared.logError("Error getting MDM enrollment time: \(error)")
    }

    return "Unknown"
}

func getMDMUrl() async -> String {
    do {
        let commandOutput = try await ExecutionService.executeCommand(
            "/usr/bin/profiles",
            with: ["status", "-type", "enrollment"]
        )

        // Process the command output
        let lines = commandOutput.split(separator: "\n")
        for line in lines {
            if line.contains("MDM server") {
                let url = line.split(separator: "https://").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                return url ?? "Unknown"
            }
        }
    } catch {
        Logger.shared.logError("Error getting MDM URL: \(error)")
    }

    return "Unknown"
}

func getMDMStatus() async -> [String: String] {
    var mdmDetails: [String: String] = ["ABM": "", "Enrolled": "", "EnrollmentDate": ""]
    
    do {
        let commandOutput = try await ExecutionService.executeCommand(
            "/usr/bin/profiles",
            with: ["status", "-type", "enrollment"]
        )
        
        // Process the command output
        let lines = commandOutput.split(separator: "\n")
        for line in lines {
            if line.contains("Enrolled via DEP") {
                let abm = line.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                mdmDetails["ABM"] = (abm == "Yes") ? "Yes" : "No"
            }
            if line.contains("MDM enrollment") {
                let enrolled = line.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                mdmDetails["Enrolled"] = ((enrolled?.contains("Yes")) != nil) ? enrolled : "No"
            }
        }
        
        // Add the enrollment date
        mdmDetails["EnrollmentDate"] = await getMDMEnrollmentTime()
        
    } catch {
        Logger.shared.logError("Error getting MDM status: \(error)")
    }
    
    return mdmDetails
}

func getMDMStatusNoEnrollmentTime() async -> [String: String] {
    var mdmDetails: [String: String] = ["ABM": "", "Enrolled": ""]
    
    do {
        let commandOutput = try await ExecutionService.executeCommand(
            "/usr/bin/profiles",
            with: ["status", "-type", "enrollment"]
        )
        
        // Process the command output
        let lines = commandOutput.split(separator: "\n")
        for line in lines {
            if line.contains("Enrolled via DEP") {
                let abm = line.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                mdmDetails["ABM"] = (abm == "Yes") ? "Yes" : "No"
            }
            if line.contains("MDM enrollment") {
                let enrolled = line.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines)
                mdmDetails["Enrolled"] = ((enrolled?.contains("Yes")) != nil) ? enrolled : "No"
            }
        }
        
    } catch {
        Logger.shared.logError("Error getting MDM status: \(error)")
    }
    
    return mdmDetails
}

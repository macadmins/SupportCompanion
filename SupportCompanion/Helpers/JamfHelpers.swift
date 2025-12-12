//
//  JamfHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-11-12.
//

import Foundation

func getLastCheckIn() async throws -> String {
    let predicate = #"process == "jamf" AND eventMessage CONTAINS "recurring check-in""#
    let args = [
        "show",
        "--predicate", predicate,
        "--last", "\(AppStateManager.shared.preferences.jamfLogPollHours)h",
        "--style", "syslog"
    ]
    
    let output: String
    output = try await ExecutionService.executeCommand("/usr/bin/log", with: args)
    
    let lines = output.split(whereSeparator: \.isNewline).map(String.init)
    guard let lastLine = lines.reversed().first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
		Logger.shared.logDebug("No log entry found for Jamf check-ins")
        return "Unknown"
    }
    
    let parts = lastLine.split(separator: " ").map(String.init)
	guard parts.count >= 2 else {
		Logger.shared.logDebug("Unexpected log line format for Jamf check-ins: \(lastLine)")
		return "Unknown"
	}
    
    let tsCandidate = parts[0] + " " + parts[1]
    guard let tsDate = parseUnifiedLogTimestamp(tsCandidate) else {
		Logger.shared.logDebug("Failed to parse timestamp from log line for Jamf check-ins: \(lastLine)")
        return "Unknown"
    }
    
	Logger.shared.logDebug("Last Jamf check-in was on: \(tsDate)")
    return timeAgoString(since: tsDate)
}

func getLastInventoryUpdate() async throws -> String {
    let predicate = #"process == "jamf" AND eventMessage CONTAINS "Submitting data""#
    let args: [String] = [
        "show",
        "--predicate", predicate,
		"--last", "\(AppStateManager.shared.preferences.jamfLogPollHours)h",
        "--style", "syslog"
    ]
    
    let output: String
    output = try await ExecutionService.executeCommand("/usr/bin/log", with: args)
    
    let lines = output.split(whereSeparator: \.isNewline).map(String.init)
    guard let lastLine = lines.reversed().first(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else {
		Logger.shared.logDebug("No log entry found for Jamf inventory update.")
        return "Unknown"
    }
    
    let parts = lastLine.split(separator: " ").map(String.init)
	guard parts.count >= 2 else {
		Logger.shared.logDebug("Unexpected output format from Jamf log: \(lastLine)")
		return "Unknown"
	}
    
    let tsCandidate = parts[0] + " " + parts[1]
    guard let tsDate = parseUnifiedLogTimestamp(tsCandidate) else {
		Logger.shared.logDebug("Failed to parse timestamp from Jamf log entry: \(lastLine)")
        return "Unknown"
    }
    
	Logger.shared.logDebug("Last Jamf inventory update was on \(tsDate)")
    return timeAgoString(since: tsDate)
}

func getJamfUrl() async throws -> String {
    let prefPlist = "/Library/Preferences/com.jamfsoftware.jamf.plist"
    
    guard FileManager.default.fileExists(atPath: prefPlist) else {
        Logger.shared.logError("Could not find Jamf preferences plist at \(prefPlist). Is Jamf running?")
        return "Unknown"
    }
    
    let args = ["read", prefPlist, "jss_url"]
    let output: String
    output = try await ExecutionService.executeCommand("/usr/bin/defaults", with: args)
    return output
}

func getJamfId() async throws -> String {
    let args = ["recon", "-concurrent"]
    let output = try await ExecutionService.executeCommandPrivileged("/usr/local/bin/jamf", arguments: args)
    
    if let rangeStart = output.range(of: "<computer_id>"),
       let rangeEnd = output.range(of: "</computer_id>", range: rangeStart.upperBound..<output.endIndex) {
        let idSubstring = output[rangeStart.upperBound..<rangeEnd.lowerBound]
        let trimmed = idSubstring.trimmingCharacters(in: .whitespacesAndNewlines)
        let digitsOnly = trimmed.filter { $0.isNumber }
        if !digitsOnly.isEmpty {
            return digitsOnly
        }
    }
    
    if let regex = try? NSRegularExpression(pattern: #"<computer_id>\s*([0-9]+)\s*</computer_id>"#, options: []) {
        let ns = output as NSString
        let range = NSRange(location: 0, length: ns.length)
        if let match = regex.firstMatch(in: output, options: [], range: range),
           match.numberOfRanges >= 2 {
            let id = ns.substring(with: match.range(at: 1))
            if !id.isEmpty {
                return id
            }
        }
    }
    
    Logger.shared.logError("Failed to parse Jamf computer_id from recon output")
    return "Unknown"
}

private func parseUnifiedLogTimestamp(_ s: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSZZZZZ"
    if let d = formatter.date(from: s) { return d }
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSZZZZZ"
    if let d = formatter.date(from: s) { return d }
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSS"
    if let d = formatter.date(from: s) { return d }
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
    if let d = formatter.date(from: s) { return d }
    return nil
}

private func timeAgoString(since date: Date, now: Date = Date()) -> String {
    let seconds = Int(now.timeIntervalSince(date))
    if seconds < 0 {
		return Constants.General.justNow
    }
    if seconds < 60 {
        if seconds == 1 {
			return "1 \(Constants.General.second) \(Constants.General.ago)"
        }
        return "\(seconds) \(Constants.General.seconds) \(Constants.General.ago)"
    }
    let minutes = seconds / 60
    if minutes < 60 {
        if minutes == 1 {
            return "1 \(Constants.General.minute) \(Constants.General.ago)"
        }
        return "\(minutes) \(Constants.General.minutes) \(Constants.General.ago)"
    }
    let hours = minutes / 60
    if hours < 24 {
        if hours == 1 {
            return "1 \(Constants.General.hour) \(Constants.General.ago)"
        }
        return "\(hours) \(Constants.General.hours) \(Constants.General.ago)"
    }
    let days = hours / 24
    if days == 1 {
        return "1 \(Constants.General.day) \(Constants.General.ago)"
    }
    return "\(days) \(Constants.General.daysAgo)"
}

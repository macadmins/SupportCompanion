//
//  IntuneLogParser.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-03.
//

import Foundation


class IntuneLogParser {
    // Input directory and output file paths
    let inputDirectory = "/Library/Logs/Microsoft/Intune/"

    // Regular expression pattern for a date
    let datePattern = #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}:\d{3}"#

    // Function to parse log files
    func parseLogFiles() async -> [[String: Any]] {
        var latestEntries: [String: [String: Any]] = [:]
        let fileManager = FileManager.default
        
        // Get all log files in the input directory
        guard let files = try? fileManager.contentsOfDirectory(atPath: inputDirectory) else {
            Logger.shared.logError("Failed to read directory")
            return []
        }
        
        let logFiles = files.filter { $0.hasPrefix("IntuneMDMDaemon") && $0.hasSuffix(".log") }
        
        for logFile in logFiles {
            let filePath = (inputDirectory as NSString).appendingPathComponent(logFile)
            Logger.shared.logDebug("Processing file: \(filePath)")
            
            guard let fileContents = try? String(contentsOfFile: filePath) else {
                Logger.shared.logError("Failed to read file: \(filePath)")
                continue
            }
            
            let lines = fileContents.split(separator: "\n")
            for line in lines {
                let fields = line.split(separator: "|").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                guard fields.count > 0, let date = fields.first, date.range(of: datePattern, options: .regularExpression) != nil else {
                    continue
                }
                
                var entry: [String: Any] = [
                    "Date": fields[0],
                    "Service": fields.indices.contains(1) ? fields[1] : "",
                    "Type": fields.indices.contains(2) ? fields[2] : "",
                    "ID": fields.indices.contains(3) ? fields[3] : "",
                    "ServiceType": fields.indices.contains(4) ? fields[4] : "",
                ]
                
                // Parse Info field
                if fields.indices.contains(5) {
                    let infoItems = fields[5].split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    var infoDict: [String: String] = [:]
                    
                    for item in infoItems {
                        let keyValue = item.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        if keyValue.count == 2 {
                            let key = keyValue[0]
                            let value = keyValue[1]
                            
                            // If the key contains a period, handle it as a message key
                            if key.contains("."), infoDict["Message"] == nil {
                                let parts = key.split(separator: ".", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                if parts.count == 2 {
                                    infoDict["Message"] = parts[0]
                                    infoDict[parts[1]] = value
                                }
                            } else {
                                infoDict[key] = value
                            }
                        }
                    }
                    
                    entry["Info"] = infoDict
                }
                
                // Process only AppDetector entries
                if let serviceType = entry["ServiceType"] as? String, serviceType == "AppDetector",
                let info = entry["Info"] as? [String: String],
                let appName = info["AppName"] {
                    if let existingEntry = latestEntries[appName],
                    let existingDate = existingEntry["Date"] as? String,
                    existingDate >= fields[0] {
                        continue
                    }
                    latestEntries[appName] = entry
                }
            }
        }
        
        return Array(latestEntries.values)
    }
}

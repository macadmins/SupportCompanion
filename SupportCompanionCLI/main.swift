//
//  main.swift
//  SupportCompanionCLI
//
//  Created by Tobias Almén on 2024-12-03.
//

import Foundation

struct SupportCompanionCLI {
    static func main() {
        let arguments = CommandLine.arguments

        guard arguments.count > 1 else {
            printUsage()
            return
        }

        let command = arguments[1]

        switch command {
        case "version":
            printAppVersion()
        case "reset":
            resetUserDefaults()
            print("UserDefaults have been reset.")
        case "prefs":
            printPreferencesStatus()
        case "help":
            printUsage()
        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    static func printAppVersion() {
        if let version = getAppVersion() {
            print("Support Companion Version: \(version)")
        } else {
            print("Failed to retrieve version.")
        }
    }

    static func getAppVersion() -> String? {
        guard let resourceBundleURL = Bundle.main.bundleURL
            .deletingLastPathComponent() // Resources folder
            .deletingLastPathComponent() // App bundle
            .appendingPathComponent("/Contents/Info.plist") as? URL else {
            return nil
        }
        
        if let plistData = NSDictionary(contentsOf: resourceBundleURL) {
            return plistData["CFBundleShortVersionString"] as? String
        }
        
        return nil
    }

    static func resetUserDefaults() {
        // Reinitialize preferences
        let preferences = Preferences()
        preferences.resetUserDefaults()
    }

    static func printPreferencesStatus() {
        let bundleIdentifier = "com.github.macadmins.SupportCompanion"
        
        print("Current UserDefaults values for \(bundleIdentifier):")
        
        // Execute the defaults read command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        process.arguments = ["read", bundleIdentifier]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print(output)
            } else {
                print("No UserDefaults values found or an error occurred.")
            }
        } catch {
            print("Error reading UserDefaults: \(error.localizedDescription)")
        }
    }

    static func printUsage() {
        print("""
        Usage: SupportCompanionCLI <command>
        
        Commands:
          version    Output the app's version.
          reset      Reset UserDefaults to default values.
          prefs      Output the current user defaults preferences.
          help       Show this help message.
        """)
    }
}

// Run the CLI
SupportCompanionCLI.main()

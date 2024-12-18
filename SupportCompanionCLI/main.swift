//
//  main.swift
//  SupportCompanionCLI
//
//  Created by Tobias Almén on 2024-12-03.
//

import Foundation

struct SupportCompanionCLI {
    static func main() async {
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
        case "action":
            if arguments.count > 2 {
                let actionName = arguments[2]
                let cli = SupportCompanionCLI()
                cli.triggerAction(named: actionName)
            } else {
                print("Missing action name.")
                printUsage()
            }
        case "battery":
            getBatteryInfo()
        case "device":
            getDeviceInfo()
        case "storage":
            getStorageInfo()
        case "mdm":
            await getMDMInfo()
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

    func triggerAction(named actionName: String) {
        let url = "supportcompanion://run?action=\(actionName)"
        if actionName.isEmpty {
            print("Action name is empty. Please provide an action name.")
            return
        }
        print("""
        🚀 Action Triggered
        -----------------------
        Action: \(actionName)

        Authentication might be required to run this action.
        """)
        let process = Process()
        process.launchPath = "/usr/bin/open"
        process.arguments = [url]
        process.launch()
        process.waitUntilExit()
    }

    static func getDeviceInfo() {
        let hostName = getHostName() ?? "Unknown"
        let ram = getRAMSize()
        let model = getModelName()
        let serial = getSerialNumber() ?? "Unknown"
        let processor = getCPUName() ?? "Unknown"
        let ip = getAllIPAddresses().joined(separator: ", ")
        let lastReboot = getLastRestartMinutes() ?? 0
        let osVersion = getOSVersion()
        let osBuild = getOSBuild()

        var formattedLastRestart: String {
            if lastReboot >= 1440 { // 1440 minutes in a day
                let days = lastReboot / 1440
                return "\(days) \(Constants.General.daysAgo)"
            } else if lastReboot >= 60 { // More than an hour
                let hours = lastReboot / 60
                return "\(hours) \(Constants.General.hours)"
            } else { // Less than an hour
                return "\(lastReboot) \(Constants.General.minutes)"
            }
        }

        print("""
        💻 Device Information
        -----------------------
        Hostname:       \(hostName.uppercased())
        Model:          \(model)
        Serial Number:  \(serial)
        Processor:      \(processor)
        Memory:         \(ram)
        IP Address(es): \(ip)
        Last Reboot:    \(formattedLastRestart)
        OS Version:     \(osVersion)
        OS Build:       \(osBuild)
        """)
    }
    
    static func getMDMInfo() async {
        let MDMUrl = await getMDMUrl()
        let MDMStatus = await getMDMStatusNoEnrollmentTime()

        print("""
        🔒 MDM Information
        -----------------------
        Enrolled:      \(MDMStatus["Enrolled"] ?? "Unknown")
        ABM:           \(MDMStatus["ABM"] ?? "Unknown")
        MDM URL:       \(MDMUrl)
        """)
    }

    static func getStorageInfo() {
        let storageName = getStorageName()
        let storageUsage = getStorageUsagePercentage()
        let fileVaultEnabled = isFileVaultEnabled()

        let progressBar = String(repeating: "▓", count: Int(storageUsage / 10)) +
                                  String(repeating: "░", count: 10 - Int(storageUsage / 10))

        print("""
        💾 Storage Information
        -----------------------
        Storage Name:  \(storageName)
        Usage:         \(progressBar) \(storageUsage)%
        FileVault:     \(fileVaultEnabled ? "Enabled ✅" : "Disabled ❌")
        """)
    }

    static func getBatteryInfo() {
        let batteryTemp = getBatteryTemperature()
        let designCapacity = getBatteryDesignCapacity() ?? 0
        let maxCapacity = getBatteryMaxCapacity() ?? 0
        let health: Int
        if designCapacity > 0 {
            health = Int(round((Double(maxCapacity) / Double(designCapacity)) * 100))
        } else {
            health = 0
        }
        let chargingStatus = isBatteryCharging()
        let timeRemaining = getBatteryTimeRemaining() ?? "Unknown"

        print("""
        🔋 Battery Information
        -----------------------
        Health:          \(health)% 🔋
        Cycle Count:     \(String(getBatteryCycleCount() ?? 0))
        Temperature:     \(String(format: "%.1f", batteryTemp ?? 0))°C 🌡️
        Charging Status: \(chargingStatus)
        Time Remaining:  \(timeRemaining)
        """)
    }

    static func printUsage() {
        print("""
        Usage: SupportCompanionCLI <command>
        
        Commands:
          version    Output the app's version.
          reset      Reset UserDefaults to default values.
          prefs      Output the current user defaults preferences.
          action     Trigger an action by name. Provide the action name as an argument.
          battery    Output battery information.
          device     Output device information.
          storage    Output storage information.
          mdm        Output MDM information.
          help       Show this help message.
        """)
    }
}

// Run the CLI
await SupportCompanionCLI.main()

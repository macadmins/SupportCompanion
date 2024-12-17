//
//  Preferences.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-13.
//

import Foundation
import SwiftUI
import Combine

class Preferences: ObservableObject {
    enum NotificationType: String {
        case softwareUpdate = "LastSoftwareUpdateNotificationTime"
        case rebootReminder = "LastRebootReminderNotificationTime"
        case generic = "LastGenericNotificationTime"
        case appUpdate = "LastAppUpdateNotificationTime"
    }
    
    // MARK: - Notifications
    
    @AppStorage(NotificationType.softwareUpdate.rawValue) var lastSoftwareUpdateNotificationTime: String = ""
    
    @AppStorage(NotificationType.rebootReminder.rawValue) var lastRebootReminderNotificationTime: String = ""
    
    @AppStorage(NotificationType.generic.rawValue) var lastGenericNotificationTime: String = ""
    
    @AppStorage(NotificationType.appUpdate.rawValue) var lastAppUpdateNotificationTime: String = ""
    
    @AppStorage("NotificationTitle") var notificationTitle: String = "Support Companion"
    
    @AppStorage("NotificationInterval") var notificationInterval: Int = 4
    
    @AppStorage("NotifcationImage") var notificationImage: String = ""
    
    @AppStorage("SoftwareUpdateNotificationButtonText") var softwareUpdateNotificationButtonText: String = Constants.Notifications.SoftwareUpdate.UpdateNotificationButtonText
    
    @AppStorage("SoftwareUpdateNotificationCommand") var softwareUpdateNotificationCommand: String = "open \(Constants.Panels.softwareUpdates)"
    
    @AppStorage("SoftwareUpdateNotificationMessage") var softwareUpdateNotificationMessage: String = Constants.Notifications.SoftwareUpdate.UpdateNotificationMessage
    
    @AppStorage("AppUpdateNotificationMessage") var appUpdateNotificationMessage: String = Constants.Notifications.AppUpdate.UpdateNotificationMessage
    
    @AppStorage("AppUpdateNotificationButtonText") var appUpdateNotificationButtonText: String = Constants.Notifications.AppUpdate.UpdateNotificationButtonText
    
    @AppStorage("AppUpdateNotificationCommand") var appUpdateNotificationCommand: String = ""
        
    // MARK: - branding
    
    @AppStorage("BrandName") var brandName: String = "Support Companion"
    
    @AppStorage("BrandLogo") var brandLogo: String = ""
    
    @AppStorage("BrandLogoLight") var brandLogoLight: String = ""
    
    @AppStorage("AccentColor") var accentColor: String?
    
    // MARK: - Menu
    
    @AppStorage("MenuShowIdentity") var menuShowIdentity: Bool = false

    @AppStorage("MenuShowApps") var menuShowApps: Bool = true

    @AppStorage("MenuShowSelfService") var menuShowSelfService: Bool = true

    @AppStorage("MenuShowCompanyPortal") var menuShowCompanyPortal: Bool = true
    
    @AppStorage("MenuShowKnowledgeBase") var menuShowKnowledgeBase: Bool = true
    
    @AppStorage("KnowledgeBaseUrl") var knowledgeBaseUrl: String = ""

    @AppStorage("ShowLogoInTrayMenu") var showLogoInTrayMenu: Bool = true

    @AppStorage("MarkdownFilePath") var markdownFilePath: String = ""

    @AppStorage("MardownMenuLabel") var markdownMenuLabel: String = ""

    @AppStorage("MardownMenuIcon") var markdownMenuIcon: String = ""
    
    // MARK: - Actions
    
    @AppStorage("SupportPageUrl") var supportPageURL: String = ""
    
    @AppStorage("ChangePasswordMode") var changePasswordMode: String = ""
    
    @AppStorage("ChangePasswordUrl") var changePasswordUrl: String = ""
    
    @AppStorage("Mode") var mode: String = ""
    
    @Published var actions: [Action] = []
    
    @Published var hiddenActions: [String] = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
    
    @Published var logFolders: [String] = UserDefaults.standard.array(forKey: "LogFolders") as? [String] ?? []
    
    // MARK: - Desktop Info
    
    @AppStorage("DesktopInfoBackgroundOpacity") var desktopInfoBackgroundOpacity: Double = 0.001
    
    @AppStorage("DesktopInfoWindowPosition") var desktopInfoWindowPosition: String = "LowerRight"
    @Published var currentWindowPosition: String = "LowerRight"
    
    @AppStorage("ShowDesktopInfo") var showDesktopInfo: Bool = false
    
    @AppStorage("DesktopInfoFontSize") var desktopInfoFontSize: Int = 14
    
    @AppStorage("DesktopInfoLevel") var desktopInfoLevel: Int = 4
    
    @Published var desktopInfoHideItems: [String] = UserDefaults.standard.array(forKey: "DesktopInfoHideItems") as? [String] ?? []
    
    // MARK: - Home
    
    @AppStorage("CustomCardPath") var customCardPath: String = ""
    
    @Published var hiddenCards: [String] = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []
    
    private var cancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Support info
    
    @AppStorage("SupportEmail") var supportEmail: String = ""
    
    @AppStorage("SupportPhone") var supportPhone: String = ""

    // MARK: - Elevate privileges

    @AppStorage("EnableElevation") var enableElevation: Bool = false

    @AppStorage("ShowElevateTrayCard") var showElevateTrayCard: Bool = true

    @AppStorage("MaxElevationTime") var maxElevationTime: Double = 300

    @AppStorage("RequireResonForElevation") var requireReasonForElevation: Bool = true

    @AppStorage("ReasonMinLength") var reasonMinLength: Int = 10

    @AppStorage("ElevationWebhookUrl") var elevationWebhookURL: String = ""

    @AppStorage("ElevationSeverity") var elevationSeverity: Int = 6 // Default to "Informational"
    
    var mdm: String = "Unknown"
        
    init() {
        ensureDefaultsInitialized()
        
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.currentWindowPosition = self.desktopInfoWindowPosition
                }
            }
            .store(in: &cancellables)
        
        // Observe changes to UserDefaults specifically for complex types
        cancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.loadHiddenCards()
                self?.loadLogFolders()
                self?.loadActions()
                self?.loadHiddenActions()
                self?.loadDesktopInfoHideItems()
            }
        Task {
            await detectModeAndSetLogFolders()
        }
    }
    
    private func detectModeAndSetLogFolders() async {
        //if !logFolders.isEmpty {
        //    Logger.shared.logDebug("Log folders already initialized: \(logFolders)")
        //    return
        //}

        guard mode.isEmpty else {
            Logger.shared.logDebug("Mode is already set to \(mode), skipping detection.")
            return
        }

        let fileManager = FileManager.default
        let companyPortalExists = fileManager.fileExists(atPath: Constants.AppPaths.companyPortal)
        let mscExists = fileManager.fileExists(atPath: Constants.AppPaths.MSC)
        let mdmUrl = await getMDMUrl()
        
        print(mdmUrl)

        if mdmUrl != "Unknown" {
            Logger.shared.logDebug("MDM URL detected: \(mdmUrl)")
            if mdmUrl.contains("i.manage.microsoft.com") {
                Logger.shared.logDebug("MDM URL contains i.manage.microsoft.com, setting mdm to Intune.")
                mdm = "Intune"
            }
        }
        
        if companyPortalExists && mscExists {
            Logger.shared.logDebug("Both Munki and Company Portal paths exist, defaulting to Munki mode.")
            mode = Constants.modes.munki
            logFolders = ["/Library/Managed Installs/Logs", "/Library/Logs/Microsoft"]
        } else if companyPortalExists && mdm == "Intune" {
            Logger.shared.logDebug("Company Portal path exists, setting mode to Intune.")
            mode = Constants.modes.intune
            logFolders = ["/Library/Logs/Microsoft"]
        } else if mscExists {
            Logger.shared.logDebug("MSC path exists, setting mode to Munki.")
            mode = Constants.modes.munki
            logFolders = ["/Library/Managed Installs/Logs"]
        } else {
            Logger.shared.logDebug("No paths exist, defaulting mode to System Profiler.")
            mode = Constants.modes.systemProfiler
            logFolders = []
        }

        UserDefaults.standard.set(mode, forKey: "Mode")
        saveLogFoldersToDefaults()
        Logger.shared.logDebug("Final mode: \(mode), log folders: \(logFolders)")
    }

    // MARK: - Save Log Folders to UserDefaults
    private func saveLogFoldersToDefaults() {
        UserDefaults.standard.set(logFolders, forKey: "LogFolders")
        Logger.shared.logDebug("Log folders saved to UserDefaults: \(logFolders)")
    }
    
    private func loadHiddenCards() {
        // Fetch hidden cards asynchronously to avoid modifying `@Published` directly during a view update
        DispatchQueue.main.async { [weak self] in
            self?.hiddenCards = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []
        }
    }
    
    private func loadLogFolders() {
        DispatchQueue.main.async { [weak self] in
            self?.logFolders = UserDefaults.standard.array(forKey: "LogFolders") as? [String] ?? []
        }
    }
    
    private func loadHiddenActions() {
        DispatchQueue.main.async { [weak self] in
            self?.hiddenActions = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
        }
    }
    
    private func loadDesktopInfoHideItems() {
        DispatchQueue.main.async { [weak self] in
            self?.desktopInfoHideItems = UserDefaults.standard.array(forKey: "DesktopInfoHideItems") as? [String] ?? []
        }
    }
    
    private func loadActions() {
        DispatchQueue.main.async { [weak self] in
            let actions = UserDefaults.standard.array(forKey: "Actions") as? [[String: Any]] ?? []
            let newActions = actions.compactMap { dict in
                Action(
                    id: UUID(),
                    name: dict["Name"] as? String ?? "Unnamed",
                    command: dict["Command"] as? String ?? "",
                    icon: dict["Icon"] as? String,
                    isPrivileged: dict["IsPrivileged"] as? Bool ?? false,
                    description: dict["Description"] as? String ?? ""
                )
            }
            self?.actions = newActions
        }
    }
    
    struct DefaultValues {
        static let values: [String: Any] = [
            "LastSoftwareUpdateNotificationTime": "",
            "lastRebootReminderNotificationTime": "",
            "LastGenericNotificationTime": "",
            "LastAppUpdateNotificationTime": "",
            "NotificationTitle": "Support Companion",
            "NotificationInterval": 4,
            "NotificationImage": "",
            "SoftwareUpdateNotificationButtonText": Constants.Notifications.SoftwareUpdate.UpdateNotificationButtonText,
            "SoftwareUpdateNotificationCommand": "open \(Constants.Panels.softwareUpdates)",
            "SoftwareUpdateNotificationMessage": Constants.Notifications.SoftwareUpdate.UpdateNotificationMessage,
            "AppUpdateNotificationMessage": Constants.Notifications.AppUpdate.UpdateNotificationMessage,
            "AppUpdateNotificationButtonText": Constants.Notifications.AppUpdate.UpdateNotificationButtonText,
            "AppUpdateNotificationCommand": "",
            "BrandName": "Support Companion",
            "BrandLogo": "",
            "AccentColor": "",
            "MenuShowIdentity": true,
            "MenuShowApps": true,
            "MenuShowSelfService": true,
            "MenuShowCompanyPortal": true,
            "MenuShowKnowledgeBase": true,
            "KnowledgeBaseUrl": "",
            "SupportPageUrl": "",
            "ChangePasswordMode": "",
            "ChangePasswordUrl": "",
            "Mode": "",
            "DesktopInfoBackgroundOpacity": 0.001,
            "DesktopInfoWindowPosition": "LowerRight",
            "ShowDesktopInfo": false,
            "DesktopInfoFontSize": 14,
            "DesktopInfoLevel": 4,
            "SupportEmail": "",
            "SupportPhone": ""
        ]
    }

    func ensureDefaultsInitialized() {
        let defaults = UserDefaults.standard

       for (key, value) in DefaultValues.values {
            if defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
    }
    

    func resetUserDefaults() {
        let bundleIdentifier = "com.github.macadmins.SupportCompanion"
        let defaults = UserDefaults.standard

        // Clear the current UserDefaults domain
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()

        // Write all default values directly using a shell command
        for (key, value) in DefaultValues.values {
            let writeCommand: String
            if let value = value as? String {
                writeCommand = "defaults write \(bundleIdentifier) \(key) '\(value)'"
            } else if let value = value as? Bool {
                writeCommand = "defaults write \(bundleIdentifier) \(key) -bool \(value)"
            } else if let value = value as? Int {
                writeCommand = "defaults write \(bundleIdentifier) \(key) -int \(value)"
            } else if let value = value as? Double {
                writeCommand = "defaults write \(bundleIdentifier) \(key) -float \(value)"
            } else {
                Logger.shared.logError("Unsupported value type for key: \(key)")
                continue
            }

            // Execute the write command
            executeShellCommand(command: writeCommand)
        }
        
        Task {
            await detectModeAndSetLogFolders()
        }
        
        Logger.shared.logDebug("Defaults have been reset using defaults write.")
    }

    func executeShellCommand(command: String) {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        process.launch()
        process.waitUntilExit()
    }
}

extension NSNotification.Name {
    static let desktopInfoPositionChanged = NSNotification.Name("desktopInfoPositionChanged")
}

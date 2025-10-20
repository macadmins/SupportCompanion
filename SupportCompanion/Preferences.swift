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

    @AppStorage("RebootReminderDays") var rebootReminderDays: Int = 0
        
    // MARK: - branding
    
    @AppStorage("BrandName") var brandName: String = "Support Companion"
    
    @AppStorage("BrandLogo") var brandLogo: String = ""
    
    @AppStorage("BrandLogoLight") var brandLogoLight: String = ""
    
    @AppStorage("AccentColor") var accentColor: String?
    
    // MARK: - Menu
    
    @AppStorage("MenuShowIdentity") var menuShowIdentity: Bool = true

    @AppStorage("MenuShowApps") var menuShowApps: Bool = true

    @AppStorage("MenuShowSelfService") var menuShowSelfService: Bool = true

    @AppStorage("MenuShowCompanyPortal") var menuShowCompanyPortal: Bool = true
    
    @AppStorage("MenuShowKnowledgeBase") var menuShowKnowledgeBase: Bool = true
    
    @AppStorage("KnowledgeBaseUrl") var knowledgeBaseUrl: String = ""

    @AppStorage("ShowLogoInTrayMenu") var showLogoInTrayMenu: Bool = true

    @AppStorage("MarkdownFilePath") var markdownFilePath: String = ""

    @AppStorage("MarkdownMenuLabel") var markdownMenuLabel: String = ""

    @AppStorage("MarkdownMenuIcon") var markdownMenuIcon: String = ""
    
    @AppStorage("CustomCardsMenuLabel") var customCardsMenuLabel: String = ""
    
    @AppStorage("CustomCardsMenuIcon") var customCardsMenuIcon: String = ""

    @AppStorage("TrayMenuBrandingIcon") var trayMenuBrandingIcon: String = ""

    @AppStorage("TrayMenuShowIcon") var trayMenuShowIcon: Bool = true
    
    // MARK: - Actions
    
    @AppStorage("SupportPageUrl") var supportPageURL: String = ""
    
    @AppStorage("ChangePasswordMode") var changePasswordMode: String = ""
    
    @AppStorage("ChangePasswordUrl") var changePasswordUrl: String = ""
    
    @AppStorage("Mode") var mode: String = ""
    
    @Published var actions: [Action] = []
    
    @Published var hiddenActions: [String] = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
    
    @Published var logFolders: [String] = UserDefaults.standard.array(forKey: "LogFolders") as? [String] ?? []

    @Published var excludedLogFolders: [String] = UserDefaults.standard.array(forKey: "ExcludedLogFolders") as? [String] ?? []

    @AppStorage("RequirePrivilegedActionAuthentication") var requirePrivilegedActionAuthentication: Bool = true
    
    // MARK: - Desktop Info
    
    @AppStorage("DesktopInfoBackgroundOpacity") var desktopInfoBackgroundOpacity: Double = 0.001
    
    @AppStorage("DesktopInfoBackgroundFrosted") var desktopInfoBackgroundFrosted: Bool = false
    
    @AppStorage("DesktopInfoWindowPosition") var desktopInfoWindowPosition: String = "LowerRight"
    @Published var currentWindowPosition: String = "LowerRight"
    
    @AppStorage("ShowDesktopInfo") var showDesktopInfo: Bool = false
    
    @AppStorage("DesktopInfoFontSize") var desktopInfoFontSize: Int = 14
    
    @AppStorage("DesktopInfoLevel") var desktopInfoLevel: Int = 4
    
    @Published var desktopInfoHideItems: [String] = UserDefaults.standard.array(forKey: "DesktopInfoHideItems") as? [String] ?? []
    
    // MARK: - Home
    
    @AppStorage("CustomCardPath") var customCardPath: String = "" {
        didSet {
            if customCardPathPublished != customCardPath {
                if Thread.isMainThread {
                    Logger.shared.logDebug("Preferences: customCardPath didSet -> '\(customCardPath)'")
                    customCardPathPublished = customCardPath
                } else {
                    DispatchQueue.main.async { [newValue = customCardPath] in
                        Logger.shared.logDebug("Preferences: customCardPath didSet (async) -> '\(newValue)'")
                        if self.customCardPathPublished != newValue {
                            self.customCardPathPublished = newValue
                        }
                    }
                }
            }
        }
    }
    // Published mirror of customCardPath so non-View subscribers can react to changes
    @Published var customCardPathPublished: String = ""
    
    @Published var hiddenCards: [String] = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []
    
    private var cancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    // Watcher for ~/Library/Preferences to detect external defaults writes
    private var prefsDirSource: DispatchSourceFileSystemObject?
    private var prefsDirFD: Int32 = -1
    
    // MARK: - Support info
    
    @AppStorage("SupportEmail") var supportEmail: String = ""
    
    @AppStorage("SupportPhone") var supportPhone: String = ""

    // MARK: - Elevate privileges

    @AppStorage("EnableElevation") var enableElevation: Bool = false

    @AppStorage("ShowElevateTrayCard") var showElevateTrayCard: Bool = true

    @AppStorage("MaxElevationTime") var maxElevationTime: Int = 5

    @AppStorage("RequireResonForElevation") var requireReasonForElevation: Bool = true

    @AppStorage("ReasonMinLength") var reasonMinLength: Int = 10

    @AppStorage("ElevationWebhookUrl") var elevationWebhookURL: String = ""

    @AppStorage("ElevationSeverity") var elevationSeverity: Int = 6 // Default to "Informational"
    
    var mdm: String = "Unknown"
        
    init() {
        ensureDefaultsInitialized()
        startWatchingCustomCardPath()

        // Initialize published mirror values from current AppStorage
        self.customCardPathPublished = self.customCardPath
        
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
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Explicitly pull latest CustomCardPath from defaults (helps when @AppStorage in classes doesn't auto-refresh)
                let latestPath = UserDefaults.standard.string(forKey: "CustomCardPath") ?? ""
                if self.customCardPath != latestPath {
                    Logger.shared.logDebug("Preferences: observed defaults change for CustomCardPath -> '\(latestPath)'")
                    self.customCardPath = latestPath
                }
                if self.customCardPathPublished != latestPath {
                    self.customCardPathPublished = latestPath
                }

                self.loadHiddenCards()
                self.loadLogFolders()
                self.loadExcludedLogFolders()
                self.loadActions()
                self.loadHiddenActions()
                self.loadDesktopInfoHideItems()
            }
        Task {
            await detectModeAndSetLogFolders()
        }
    }

    private func startWatchingCustomCardPath() {
        // Always watch the Preferences directory; this catches atomic saves and initial file creation
        let domain = "com.github.macadmins.SupportCompanion"
        let prefsPlistURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(domain).plist")
        let prefsDirURL = prefsPlistURL.deletingLastPathComponent()

        let fd = open(prefsDirURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Logger.shared.logError("Preferences: failed to open preferences directory for watching: \(prefsDirURL.path)")
            return
        }
        prefsDirFD = fd
        let queue = DispatchQueue(label: "com.github.macadmins.SupportCompanion.PrefsWatch")
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )
        src.setCancelHandler { [fd] in
            close(fd)
        }
        src.setEventHandler { [weak self] in
            guard let self = self else { return }
            // Read value directly from the plist to avoid UserDefaults caching
            var latest = ""
            if let dict = NSDictionary(contentsOf: prefsPlistURL) as? [String: Any],
               let s = dict["CustomCardPath"] as? String {
                latest = s
            } else {
                latest = UserDefaults.standard.string(forKey: "CustomCardPath") ?? ""
            }
            DispatchQueue.main.async {
                if self.customCardPathPublished != latest {
                    Logger.shared.logInfo("Prefs watcher: CustomCardPath -> '\(latest)'")
                    if self.customCardPath != latest {
                        self.customCardPath = latest
                    }
                    self.customCardPathPublished = latest
                }
            }
        }
        src.resume()
        prefsDirSource = src
        Logger.shared.logDebug("Preferences: started watching \(prefsDirURL.path)")
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
        let selfServiceExists = fileManager.fileExists(atPath: Constants.AppPaths.selfService)
        let mscExists = fileManager.fileExists(atPath: Constants.AppPaths.MSC)
        let mdmUrl = await getMDMUrl()
        
        if mdmUrl != "Unknown" {
            Logger.shared.logDebug("MDM URL detected: \(mdmUrl)")
            if mdmUrl.contains("i.manage.microsoft.com") {
                Logger.shared.logDebug("MDM URL contains i.manage.microsoft.com, setting mdm to Intune.")
                mdm = "Intune"
            } else if mdmUrl.contains("jamf") {
                Logger.shared.logDebug("MDM URL contains jamf, setting mdm to Jamf.")
                mdm = "Jamf"
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
        } else if selfServiceExists && mscExists {
            Logger.shared.logDebug("Both Munki and Self Service paths exist, defaulting to Munki mode.")
            mode = Constants.modes.munki
            logFolders = ["/Library/Managed Installs/Logs", "/var/log/jamf.log"]
        } else if selfServiceExists && mdm == "Jamf" {
            Logger.shared.logDebug("Self Service path exists, setting mode to Jamf.")
            mode = Constants.modes.jamf
            logFolders = ["/var/log/jamf.log"]
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

    private func loadExcludedLogFolders() {
        DispatchQueue.main.async { [weak self] in
            self?.excludedLogFolders = UserDefaults.standard.array(forKey: "ExcludedLogFolders") as? [String] ?? []
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
                    description: dict["Description"] as? String ?? "",
                    buttonLabel: dict["ButtonLabel"] as? String ?? "Run"
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

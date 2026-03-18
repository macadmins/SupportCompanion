//
//  Preferences.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-13.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class Preferences: ObservableObject {

    // MARK: - Domain sub-objects

    let branding = BrandingPreferences()
    let notifications = NotificationPreferences()
    let elevation = ElevationPreferences()
    let desktopInfo = DesktopInfoPreferences()

    // MARK: - Menu

    @AppStorage("MenuShowIdentity") var menuShowIdentity: Bool = true
    @AppStorage("MenuShowApps") var menuShowApps: Bool = true
    @AppStorage("MenuShowSelfService") var menuShowSelfService: Bool = true
    @AppStorage("CompanyPortalUrl") var companyPortalUrl: String = ""
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
    @AppStorage("RequirePrivilegedActionAuthentication") var requirePrivilegedActionAuthentication: Bool = true

    @Published var actions: [Action] = []
    @Published var hiddenActions: [String] = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
    @Published var logFolders: [String] = UserDefaults.standard.array(forKey: "LogFolders") as? [String] ?? []
    @Published var excludedLogFolders: [String] = UserDefaults.standard.array(forKey: "ExcludedLogFolders") as? [String] ?? []

    // MARK: - Home / Cards

    @AppStorage("CustomCardPath") var customCardPath: String = "" {
        didSet {
            if customCardPathPublished != customCardPath {
                if Thread.isMainThread {
                    Logger.shared.logDebug("Preferences: customCardPath didSet -> '\(customCardPath)'")
                    customCardPathPublished = customCardPath
                } else {
                    let newValue = customCardPath
                    Task { @MainActor in
                        Logger.shared.logDebug("Preferences: customCardPath didSet (async) -> '\(newValue)'")
                        if self.customCardPathPublished != newValue {
                            self.customCardPathPublished = newValue
                        }
                    }
                }
            }
        }
    }
    /// Published mirror of customCardPath so non-View subscribers can react to changes.
    @Published var customCardPathPublished: String = ""

    @Published var hiddenCards: [String] = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []

    // MARK: - Support info

    @AppStorage("SupportEmail") var supportEmail: String = ""
    @AppStorage("SupportPhone") var supportPhone: String = ""

    // MARK: - General

    @AppStorage("RefreshSelfService") var refreshSelfService: Bool = true
    @AppStorage("JamfLogPollHours") var jamfLogPollHours: Int = 36
    @AppStorage("DebugLogging") var debugLogging: Bool = false

    var mdm: String = "Unknown"

    // MARK: - Private state

    private var cancellable: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    private var prefsDirSource: DispatchSourceFileSystemObject?
    private var prefsDirFD: Int32 = -1

    // MARK: - Init

    init() {
        ensureDefaultsInitialized()
        startWatchingCustomCardPath()

        self.customCardPathPublished = self.customCardPath

        Logger.shared.setFileDebugLogging(debugLogging)

        // Forward sub-object changes so views observing `Preferences` update too
        branding.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        notifications.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        elevation.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
        desktopInfo.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Observe UserDefaults changes for complex-type properties and the debug-logging flag
        cancellable = NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }

                let latestPath = UserDefaults.standard.string(forKey: "CustomCardPath") ?? ""
                if self.customCardPath != latestPath {
                    Logger.shared.logDebug("Preferences: observed defaults change for CustomCardPath -> '\(latestPath)'")
                    self.customCardPath = latestPath
                }
                if self.customCardPathPublished != latestPath {
                    self.customCardPathPublished = latestPath
                }

                if let anyVal = UserDefaults.standard.object(forKey: "FileDebugLogging") {
                    let latestDebug = (anyVal as? Bool) ?? (anyVal as? NSNumber)?.boolValue ?? false
                    if self.debugLogging != latestDebug {
                        self.debugLogging = latestDebug
                    }
                    Logger.shared.setFileDebugLogging(latestDebug)
                }

                self.loadHiddenCards()
                self.loadLogFolders()
                self.loadExcludedLogFolders()
                self.loadActions()
                self.loadHiddenActions()
            }

        Task {
            await detectModeAndSetLogFolders()
        }
    }

    // MARK: - File watcher for CustomCardPath

    private func startWatchingCustomCardPath() {
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
        src.setCancelHandler { [fd] in close(fd) }
        src.setEventHandler { [weak self] in
            guard let self else { return }
            var latest = ""
            if let dict = NSDictionary(contentsOf: prefsPlistURL) as? [String: Any],
               let s = dict["CustomCardPath"] as? String {
                latest = s
            } else {
                latest = UserDefaults.standard.string(forKey: "CustomCardPath") ?? ""
            }
            
            if self.customCardPathPublished != latest {
                Logger.shared.logInfo("Prefs watcher: CustomCardPath -> '\(latest)'")
                if self.customCardPath != latest {
                    self.customCardPath = latest
                }
                self.customCardPathPublished = latest
            }
        }
        src.resume()
        prefsDirSource = src
        Logger.shared.logDebug("Preferences: started watching \(prefsDirURL.path)")
    }

    // MARK: - Mode detection

    private func detectModeAndSetLogFolders() async {
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

            if let url = URL(string: mdmUrl), let host = url.host?.lowercased() {
                let pattern = #"(^|\.)manage\.microsoft\.[a-z0-9-]{2,63}$"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                    let range = NSRange(host.startIndex..<host.endIndex, in: host)
                    if regex.firstMatch(in: host, options: [], range: range) != nil {
                        Logger.shared.logDebug("MDM host '\(host)' is a manage.microsoft.* endpoint, setting MDM to Intune.")
                        mdm = "Intune"
                        return
                    }
                }
                if host.contains("jamf") {
                    Logger.shared.logDebug("MDM host '\(host)' contains 'jamf', setting MDM to Jamf.")
                    mdm = "Jamf"
                    return
                }
            } else {
                let lower = mdmUrl.lowercased()
                if lower.contains("i.manage.microsoft.com") {
                    Logger.shared.logDebug("MDM URL contains i.manage.microsoft.com, setting MDM to Intune.")
                    mdm = "Intune"
                } else if lower.contains("jamf") {
                    Logger.shared.logDebug("MDM URL contains jamf, setting MDM to Jamf.")
                    mdm = "Jamf"
                }
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

    // MARK: - Loaders

    private func saveLogFoldersToDefaults() {
        UserDefaults.standard.set(logFolders, forKey: "LogFolders")
        Logger.shared.logDebug("Log folders saved to UserDefaults: \(logFolders)")
    }

    private func loadHiddenCards() {
        self.hiddenCards = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []
    }

    private func loadLogFolders() {
        self.logFolders = UserDefaults.standard.array(forKey: "LogFolders") as? [String] ?? []
    }

    private func loadHiddenActions() {
        self.hiddenActions = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
    }

    private func loadExcludedLogFolders() {
        self.excludedLogFolders = UserDefaults.standard.array(forKey: "ExcludedLogFolders") as? [String] ?? []
    }

    private func loadActions() {
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
            self.actions = newActions
        }
    

    // MARK: - Defaults

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

    func resetUserDefaults() async {
        let bundleIdentifier = "com.github.macadmins.SupportCompanion"
        let defaults = UserDefaults.standard
        defaults.removePersistentDomain(forName: bundleIdentifier)
        defaults.synchronize()

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
            //executeShellCommand(command: writeCommand)
            _ = try? await ExecutionService.executeShellCommand(writeCommand)
        }

        Task { await detectModeAndSetLogFolders() }
        Logger.shared.logDebug("Defaults have been reset using defaults write.")
    }

    /*func executeShellCommand(command: String) {
        let process = Process()
        process.launchPath = "/bin/zsh"
        process.arguments = ["-c", command]
        process.launch()
        process.waitUntilExit()
    }*/
}

extension NSNotification.Name {
    static let desktopInfoPositionChanged = NSNotification.Name("desktopInfoPositionChanged")
}

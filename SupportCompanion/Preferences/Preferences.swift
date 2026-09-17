//
//  Preferences.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-13.
//

import Foundation
import Observation

@MainActor
@Observable
class Preferences {

    // MARK: - Domain sub-objects

    let branding = BrandingPreferences()
    let notifications = NotificationPreferences()
    let elevation = ElevationPreferences()
    let desktopInfo = DesktopInfoPreferences()

    // MARK: - Menu

    var menuShowIdentity: Bool {
        get { DefaultsStore.value(forKey: "MenuShowIdentity", default: true) }
        set { DefaultsStore.set(newValue, forKey: "MenuShowIdentity") }
    }
    var menuShowApps: Bool {
        get { DefaultsStore.value(forKey: "MenuShowApps", default: true) }
        set { DefaultsStore.set(newValue, forKey: "MenuShowApps") }
    }
    var menuShowSelfService: Bool {
        get { DefaultsStore.value(forKey: "MenuShowSelfService", default: true) }
        set { DefaultsStore.set(newValue, forKey: "MenuShowSelfService") }
    }
    var companyPortalUrl: String {
        get { DefaultsStore.value(forKey: "CompanyPortalUrl", default: "") }
        set { DefaultsStore.set(newValue, forKey: "CompanyPortalUrl") }
    }
    var menuShowCompanyPortal: Bool {
        get { DefaultsStore.value(forKey: "MenuShowCompanyPortal", default: true) }
        set { DefaultsStore.set(newValue, forKey: "MenuShowCompanyPortal") }
    }
    var menuShowKnowledgeBase: Bool {
        get { DefaultsStore.value(forKey: "MenuShowKnowledgeBase", default: true) }
        set { DefaultsStore.set(newValue, forKey: "MenuShowKnowledgeBase") }
    }
    var knowledgeBaseUrl: String {
        get { DefaultsStore.value(forKey: "KnowledgeBaseUrl", default: "") }
        set { DefaultsStore.set(newValue, forKey: "KnowledgeBaseUrl") }
    }
    var showLogoInTrayMenu: Bool {
        get { DefaultsStore.value(forKey: "ShowLogoInTrayMenu", default: true) }
        set { DefaultsStore.set(newValue, forKey: "ShowLogoInTrayMenu") }
    }
    var markdownFilePath: String {
        get { DefaultsStore.value(forKey: "MarkdownFilePath", default: "") }
        set { DefaultsStore.set(newValue, forKey: "MarkdownFilePath") }
    }
    var markdownMenuLabel: String {
        get { DefaultsStore.value(forKey: "MarkdownMenuLabel", default: "") }
        set { DefaultsStore.set(newValue, forKey: "MarkdownMenuLabel") }
    }
    var markdownMenuIcon: String {
        get { DefaultsStore.value(forKey: "MarkdownMenuIcon", default: "") }
        set { DefaultsStore.set(newValue, forKey: "MarkdownMenuIcon") }
    }
    var customCardsMenuLabel: String {
        get { DefaultsStore.value(forKey: "CustomCardsMenuLabel", default: "") }
        set { DefaultsStore.set(newValue, forKey: "CustomCardsMenuLabel") }
    }
    var customCardsMenuIcon: String {
        get { DefaultsStore.value(forKey: "CustomCardsMenuIcon", default: "") }
        set { DefaultsStore.set(newValue, forKey: "CustomCardsMenuIcon") }
    }
    var trayMenuBrandingIcon: String {
        get { DefaultsStore.value(forKey: "TrayMenuBrandingIcon", default: "") }
        set { DefaultsStore.set(newValue, forKey: "TrayMenuBrandingIcon") }
    }
    var trayMenuShowIcon: Bool {
        get { DefaultsStore.value(forKey: "TrayMenuShowIcon", default: true) }
        set { DefaultsStore.set(newValue, forKey: "TrayMenuShowIcon") }
    }

    // MARK: - Actions

    var supportPageURL: String {
        get { DefaultsStore.value(forKey: "SupportPageUrl", default: "") }
        set { DefaultsStore.set(newValue, forKey: "SupportPageUrl") }
    }
    var changePasswordMode: String {
        get { DefaultsStore.value(forKey: "ChangePasswordMode", default: "") }
        set { DefaultsStore.set(newValue, forKey: "ChangePasswordMode") }
    }
    var changePasswordUrl: String {
        get { DefaultsStore.value(forKey: "ChangePasswordUrl", default: "") }
        set { DefaultsStore.set(newValue, forKey: "ChangePasswordUrl") }
    }
    var mode: String {
        get { DefaultsStore.value(forKey: "Mode", default: "") }
        set { DefaultsStore.set(newValue, forKey: "Mode") }
    }
    // Only an administrator may turn off authentication for privileged actions. See TrustedPreferences.
    var requirePrivilegedActionAuthentication: Bool {
        TrustedPreferences.bool(forKey: "RequirePrivilegedActionAuthentication", default: true)
    }

    /// Parsed from the Actions preference; reloaded when defaults change. See loadActions().
    var actions: [Action] = []
    var hiddenActions: [String] {
        get { DefaultsStore.value(forKey: "HiddenActions", default: []) }
        set { DefaultsStore.set(newValue, forKey: "HiddenActions") }
    }
    var logFolders: [String] {
        get { DefaultsStore.value(forKey: "LogFolders", default: []) }
        set { DefaultsStore.set(newValue, forKey: "LogFolders") }
    }
    var excludedLogFolders: [String] {
        get { DefaultsStore.value(forKey: "ExcludedLogFolders", default: []) }
        set { DefaultsStore.set(newValue, forKey: "ExcludedLogFolders") }
    }

    // MARK: - Home / Cards

    var customCardPath: String {
        get { DefaultsStore.value(forKey: "CustomCardPath", default: "") }
        set { DefaultsStore.set(newValue, forKey: "CustomCardPath") }
    }

    var hiddenCards: [String] {
        get { DefaultsStore.value(forKey: "HiddenCards", default: []) }
        set { DefaultsStore.set(newValue, forKey: "HiddenCards") }
    }

    // MARK: - Support info

    var supportEmail: String {
        get { DefaultsStore.value(forKey: "SupportEmail", default: "") }
        set { DefaultsStore.set(newValue, forKey: "SupportEmail") }
    }
    var supportPhone: String {
        get { DefaultsStore.value(forKey: "SupportPhone", default: "") }
        set { DefaultsStore.set(newValue, forKey: "SupportPhone") }
    }

    // MARK: - General

    var refreshSelfService: Bool {
        get { DefaultsStore.value(forKey: "RefreshSelfService", default: true) }
        set { DefaultsStore.set(newValue, forKey: "RefreshSelfService") }
    }
    var jamfLogPollHours: Int {
        get { DefaultsStore.value(forKey: "JamfLogPollHours", default: 36) }
        set { DefaultsStore.set(newValue, forKey: "JamfLogPollHours") }
    }
    var debugLogging: Bool {
        get { DefaultsStore.value(forKey: "DebugLogging", default: false) }
        set { DefaultsStore.set(newValue, forKey: "DebugLogging") }
    }

    var mdm: String = "Unknown"

    // MARK: - Private state

    @ObservationIgnored private var defaultsObserver: NSObjectProtocol?
    @ObservationIgnored private var prefsDirSource: DispatchSourceFileSystemObject?

    // MARK: - Init

    init() {
        ensureDefaultsInitialized()
        loadActions()
        Logger.shared.setFileDebugLogging(fileDebugLoggingEnabled)

        // Plain preferences are read from UserDefaults through DefaultsStore and stay current on their own.
        // Only derived state needs reloading here.
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                Logger.shared.setFileDebugLogging(self.fileDebugLoggingEnabled)
                self.loadActions()
            }
        }

        startWatchingPreferencesDirectory()

        Task {
            await detectModeAndSetLogFolders()
        }
    }

    private var fileDebugLoggingEnabled: Bool {
        let value = UserDefaults.standard.object(forKey: "FileDebugLogging")
        return (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? debugLogging
    }

    // MARK: - Preferences file watcher

    /// `defaults write` from another process doesn't post `UserDefaults.didChangeNotification` in this
    /// process, so watch the preferences directory and tell DefaultsStore when the plist changes.
    private func startWatchingPreferencesDirectory() {
        let prefsDirURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences")

        let fd = open(prefsDirURL.path, O_EVTONLY)
        guard fd >= 0 else {
            Logger.shared.logError("Preferences: failed to open preferences directory for watching: \(prefsDirURL.path)")
            return
        }
        let queue = DispatchQueue(label: "com.github.macadmins.SupportCompanion.PrefsWatch")
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: queue
        )
        let plistPath = prefsDirURL.appendingPathComponent("com.github.macadmins.SupportCompanion.plist").path
        var lastModified = (try? FileManager.default.attributesOfItem(atPath: plistPath))?[.modificationDate] as? Date

        src.setCancelHandler { [fd] in close(fd) }
        src.setEventHandler { [weak self] in
            // Other apps write to this directory constantly; only react when our plist changed
            let modified = (try? FileManager.default.attributesOfItem(atPath: plistPath))?[.modificationDate] as? Date
            guard modified != lastModified else { return }
            lastModified = modified
            Task { @MainActor [weak self] in
                DefaultsStore.shared.defaultsChanged()
                self?.loadActions()
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
                    }
                }
                if mdm == "Unknown" && host.contains("jamf") {
                    Logger.shared.logDebug("MDM host '\(host)' contains 'jamf', setting MDM to Jamf.")
                    mdm = "Jamf"
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
            mode = Constants.Modes.munki
            logFolders = ["/Library/Managed Installs/Logs", "/Library/Logs/Microsoft"]
        } else if companyPortalExists && mdm == "Intune" {
            Logger.shared.logDebug("Company Portal path exists, setting mode to Intune.")
            mode = Constants.Modes.intune
            logFolders = ["/Library/Logs/Microsoft"]
        } else if selfServiceExists && mscExists {
            Logger.shared.logDebug("Both Munki and Self Service paths exist, defaulting to Munki mode.")
            mode = Constants.Modes.munki
            logFolders = ["/Library/Managed Installs/Logs", "/var/log/jamf.log"]
        } else if selfServiceExists && mdm == "Jamf" {
            Logger.shared.logDebug("Self Service path exists, setting mode to Jamf.")
            mode = Constants.Modes.jamf
            logFolders = ["/var/log/jamf.log"]
        } else if mscExists {
            Logger.shared.logDebug("MSC path exists, setting mode to Munki.")
            mode = Constants.Modes.munki
            logFolders = ["/Library/Managed Installs/Logs"]
        } else {
            Logger.shared.logDebug("No paths exist, defaulting mode to System Profiler.")
            mode = Constants.Modes.systemProfiler
            logFolders = []
        }

        Logger.shared.logDebug("Final mode: \(mode), log folders: \(logFolders)")
    }

    // MARK: - Actions

    private func loadActions() {
        // Privileged actions run as root through the helper, so they must come from an administrator.
        // Actions a user wrote to their own defaults domain still work, but never with privileges.
        let trustedActions = TrustedPreferences.object(forKey: "Actions") as? [[String: Any]]
        let actions = trustedActions ?? UserDefaults.standard.array(forKey: "Actions") as? [[String: Any]] ?? []
        let allowPrivileged = trustedActions != nil

        let newActions = actions.map { dict in
            let name = dict["Name"] as? String ?? "Unnamed"
            let requestsPrivileges = dict["IsPrivileged"] as? Bool ?? false
            if requestsPrivileges && !allowPrivileged {
                Logger.shared.logError("Ignoring IsPrivileged for action '\(name)': Actions are not set by a configuration profile or /Library/Preferences")
            }
            return Action(
                id: UUID(),
                name: name,
                command: dict["Command"] as? String ?? "",
                icon: dict["Icon"] as? String,
                isPrivileged: requestsPrivileges && allowPrivileged,
                description: dict["Description"] as? String ?? "",
                buttonLabel: dict["ButtonLabel"] as? String ?? "Run"
            )
        }
        // Actions get new ids on every parse; only publish when the content actually changed
        if newActions.map(\.contentKey) != self.actions.map(\.contentKey) {
            self.actions = newActions
        }
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
            _ = try? await ExecutionService.executeShellCommand(writeCommand)
        }

        Task { await detectModeAndSetLogFolders() }
        Logger.shared.logDebug("Defaults have been reset using defaults write.")
    }
}

extension NSNotification.Name {
    static let desktopInfoPositionChanged = NSNotification.Name("desktopInfoPositionChanged")
}

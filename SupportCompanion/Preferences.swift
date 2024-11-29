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
    
    @AppStorage("NotificationInterval") var notificationInterval: Int = 1
    
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
    
    @AppStorage("AccentColor") var accentColor: String?
    
    // MARK: - Menu
    
    @AppStorage("MenuShowCompanyPortal") var menuShowCompanyPortal: Bool = true
    
    @AppStorage("MenuShowKnowledgeBase") var menuShowKnowledgeBase: Bool = true
    
    @AppStorage("KnowledgeBaseUrl") var knowledgeBaseUrl: String = ""
    
    // MARK: - Actions
    
    @AppStorage("SupportPageURL") var supportPageURL: String = ""
    
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
    
    @AppStorage("ShowDesktopInfo") var showDesktopInfo: Bool = true
    
    @AppStorage("DesktopInfoFontSize") var desktopInfoFontSize: Int = 14
    
    @AppStorage("DesktopInfoLevel") var desktopInfoLevel: Int = 4
    
    @Published var desktopInfoCustomItems: [String] = UserDefaults.standard.array(forKey: "DesktopInfoCustomItems") as? [String] ?? []
    
    // MARK: - Home
    
    @AppStorage("CustomCardPath") var customCardPath: String = ""
    
    @Published var hiddenCards: [String] = UserDefaults.standard.array(forKey: "HiddenCards") as? [String] ?? []
    
    private var cancellable: AnyCancellable?
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Support info
    
    @AppStorage("SupportEmail") var supportEmail: String = ""
    
    @AppStorage("SupportPhone") var supportPhone: String = ""
    
    init() {
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
                self?.loadDesktopInfoCustomItems()
            }
        
        detectModeAndSetLogFolders()
    }
    
    private func detectModeAndSetLogFolders() {
        // Avoid overwriting if UserDefaults has pre-set log folders
        if !logFolders.isEmpty {
            Logger.shared.logDebug("Log folders already initialized: \(logFolders)")
            return
        }

        guard mode.isEmpty else {
            Logger.shared.logDebug("Mode is already set to \(mode), skipping detection.")
            return
        }

        let fileManager = FileManager.default
        let companyPortalExists = fileManager.fileExists(atPath: Constants.AppPaths.companyPortal)
        let mscExists = fileManager.fileExists(atPath: Constants.AppPaths.MSC)

        if companyPortalExists && mscExists {
            Logger.shared.logDebug("Both Munki and Company Portal paths exist, defaulting to Munki mode")
            mode = Constants.modes.munki
            logFolders = ["/Library/Managed Installs/Logs", "/Library/Logs/Microsoft"]
        } else if companyPortalExists {
            Logger.shared.logDebug("Company Portal path exists, setting mode to Intune")
            mode = Constants.modes.intune
            logFolders = ["/Library/Logs/Microsoft"]
        } else if mscExists {
            Logger.shared.logDebug("MSC path exists, setting mode to Munki")
            mode = Constants.modes.munki
            logFolders = ["/Library/Managed Installs/Logs"]
        } else {
            Logger.shared.logDebug("No paths exist, defaulting mode to System Profiler")
            mode = Constants.modes.systemProfiler
            logFolders = []
        }

        saveLogFoldersToDefaults()
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
            self?.hiddenCards = UserDefaults.standard.array(forKey: "HiddenActions") as? [String] ?? []
        }
    }
    
    private func loadDesktopInfoCustomItems() {
        DispatchQueue.main.async { [weak self] in
            self?.desktopInfoCustomItems = UserDefaults.standard.array(forKey: "DesktopInfoCustomItems") as? [String] ?? []
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
}

extension NSNotification.Name {
    static let desktopInfoPositionChanged = NSNotification.Name("desktopInfoPositionChanged")
}

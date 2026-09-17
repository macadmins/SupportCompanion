//
//  NotificationService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import UserNotifications
import SwiftUI

@MainActor
class NotificationService {
    private let appState: AppStateManager
    /// Every category registered by this app. Registering replaces the whole set, so it's kept here and
    /// always registered in full, rather than read back and merged by notifications sent at the same time.
    private static var categories: [String: UNNotificationCategory] = [:]
    /// Categories registered by earlier launches, which notifications still in Notification Center use.
    /// Read once, before this launch registers anything.
    private static var loadedEarlierCategories = false
    
    init(appState: AppStateManager) {
        self.appState = appState
    }
    
    private func prepareImageForNotification(imagePath: String) -> URL? {
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = URL(fileURLWithPath: imagePath).lastPathComponent
        let tempFileURL = tempDirectory.appendingPathComponent(fileName)

        do {
            // Check if the file already exists in the temporary directory
            if !FileManager.default.fileExists(atPath: tempFileURL.path) {
                // Copy the file to the temporary directory
                try FileManager.default.copyItem(at: URL(fileURLWithPath: imagePath), to: tempFileURL)
            }
            return tempFileURL
        } catch {
            Logger.shared.logError("Failed to prepare image for notification: \(error.localizedDescription)")
            return nil
        }
    }

    /// Command that updates every Fleet title with an update available, for update notifications.
    static let fleetUpdateAllCommand = "fleet-update-all"
    /// Followed by a title id: quits that app and retries its install.
    static let fleetQuitAndRetryCommand = "fleet-quit-and-retry:"

    /// - Parameters:
    ///   - command: Run by the button. `demote`, `fleet-update-all` and `open supportcompanion://…` are handled in the app.
    ///   - openURL: A `supportcompanion://` page opened when the notification itself is clicked.
    func sendNotification(
        message: String,
        buttonText: String? = nil,
        command: String? = nil,
        openURL: String? = nil,
        notificationType: NotificationType
    ) {
        guard appState.preferences.notifications.notificationInterval > 0 else {
            Logger.shared.logDebug("Notification interval set to 0, skipping notification")
            return
        }
        
        let imagePath = appState.preferences.notifications.notificationImage.isEmpty ? nil : appState.preferences.notifications.notificationImage

        if notificationType != .generic {
            if let lastDate = AppStorageHelper.shared.getLastNotificationDate(for: notificationType),
            Date().timeIntervalSince(lastDate) < TimeInterval(appState.preferences.notifications.notificationInterval * 3600) {
                Logger.shared.logDebug("Notification interval for \(notificationType) not reached, skipping notification")
                return
            }
        }

        let notificationCommand = command?.isEmpty == false ? command : nil
        let content = UNMutableNotificationContent()
        content.title = appState.preferences.notifications.notificationTitle
        content.body = message
        content.sound = .default
        var userInfo: [String: Any] = ["Command": notificationCommand as Any]
        if let openURL, openURL.hasPrefix("supportcompanion://") {
            userInfo["OpenURL"] = openURL
        }
        content.userInfo = userInfo
        
        if let imagePath = imagePath, let tempURL = prepareImageForNotification(imagePath: imagePath) {
            do {
                let attachment = try UNNotificationAttachment(identifier: "image", url: tempURL, options: nil)
                content.attachments = [attachment]
            } catch {
                Logger.shared.logError("Failed to attach image: \(error.localizedDescription)")
            }
        }

        var actions: [UNNotificationAction] = []
        if let buttonText = buttonText, notificationCommand != nil {
            let action = UNNotificationAction(
                identifier: "RUN_COMMAND",
                title: buttonText,
                options: [.foreground]
            )
            actions.append(action)
        }

        // A category per button title: categories are shared, so reusing one would change the buttons of
        // notifications already delivered
        let category = UNNotificationCategory(
            identifier: actions.isEmpty ? "PLAIN" : "ACTIONABLE.\(buttonText ?? "")",
            actions: actions,
            intentIdentifiers: []
        )
        content.categoryIdentifier = category.identifier

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            await Self.register(category, in: center)
            do {
                try await center.add(request)
                Logger.shared.logDebug("Notification sent: \(message)")
                AppStorageHelper.shared.setLastNotificationDate(Date(), for: notificationType)
            } catch {
                Logger.shared.logDebug("Failed to deliver notification: \(error.localizedDescription)")
            }
        }
    }

    private static func register(_ category: UNNotificationCategory, in center: UNUserNotificationCenter) async {
        if !loadedEarlierCategories {
            let earlier = await center.notificationCategories()
            if !loadedEarlierCategories {
                loadedEarlierCategories = true
                for existing in earlier where categories[existing.identifier] == nil {
                    categories[existing.identifier] = existing
                }
            }
        }
        // Checked and registered without suspending, so notifications sent together can't undo each other
        guard categories[category.identifier] == nil else { return }
        categories[category.identifier] = category
        center.setNotificationCategories(Set(categories.values))
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier,
           let openURL = response.notification.request.content.userInfo["OpenURL"] as? String {
            Logger.shared.logDebug("Notification clicked, opening \(openURL)")
            ActionHelpers.openManagementApp(appURL: openURL)
        } else if response.actionIdentifier == "RUN_COMMAND",
            let command = response.notification.request.content.userInfo["Command"] as? String {
            Logger.shared.logDebug("Notification button clicked, running command: \(command)")
            if command == "demote" {
                Task { @MainActor in
                    AppStateManager.shared.stopDemotionTimer()
                    ElevationManager.shared.demotePrivileges { success in
                        if success {
                            Logger.shared.logDebug("Successfully demoted privileges")
                        } else {
                            Logger.shared.logError("Failed to demote privileges")
                        }
                    }
                }
            } else if command == NotificationService.fleetUpdateAllCommand {
                Task { @MainActor in
                    ActionHelpers.openManagementApp(appURL: "supportcompanion://apps")
                    await AppStateManager.shared.fleetSoftwareManager.updateAll()
                }
            } else if command.hasPrefix(NotificationService.fleetQuitAndRetryCommand),
                      let titleID = Int(command.dropFirst(NotificationService.fleetQuitAndRetryCommand.count)) {
                Task { @MainActor in
                    ActionHelpers.openManagementApp(appURL: "supportcompanion://apps")
                    await AppStateManager.shared.fleetSoftwareManager.quitAndRetry(titleID: titleID)
                }
            } else if command.hasPrefix("open supportcompanion://") {
                ActionHelpers.openManagementApp(appURL: String(command.dropFirst("open ".count)))
            } else {
                Task {
                    do {
                        _ = try await ExecutionService.executeShellCommand(command)
                    }
                    catch {
                        Logger.shared.logError("Failed to execute notificaiton command: \(error)")
                    }
                }
            }
        }
        completionHandler()
    }
}

@MainActor
class BadgeManager {
    static let shared = BadgeManager()
    private(set) var badgeCount = 0

    func incrementBadgeCount(count: Int) {
        badgeCount = count
        updateBadge()
    }

    func currentBadgeCount() -> Int {
        return badgeCount
    }

    private func updateBadge() {
        if badgeCount > 0 {
            if AppStateManager.shared.attentionCount > 0 {
                NSApplication.shared.dockTile.showsApplicationBadge = true
                NSApplication.shared.dockTile.badgeLabel = nil
                NSApplication.shared.dockTile.badgeLabel = String(badgeCount)
            } else {
                NSApplication.shared.dockTile.showsApplicationBadge = false
                NSApplication.shared.dockTile.badgeLabel = nil
            }
        } else {
            NSApplication.shared.dockTile.badgeLabel = nil
            NSApplication.shared.dockTile.showsApplicationBadge = false
        }
    }
}

enum NotificationType: String {
    case softwareUpdate
    case rebootReminder
    case appUpdate
    case generic
}


@MainActor
class AppStorageHelper {
    // Singleton instance
    static let shared = AppStorageHelper(appState: AppStateManager.shared)

    private let appState: AppStateManager

    private init(appState: AppStateManager) {
        self.appState = appState
    }

    func setLastNotificationDate(_ date: Date, for type: NotificationType) {
        let formattedDate = ISO8601DateFormatter().string(from: date)
        switch type {
        case .softwareUpdate:
            appState.preferences.notifications.lastSoftwareUpdateNotificationTime = formattedDate
        case .rebootReminder:
            appState.preferences.notifications.lastRebootReminderNotificationTime = formattedDate
        case .generic:
            appState.preferences.notifications.lastGenericNotificationTime = formattedDate
        case .appUpdate:
            appState.preferences.notifications.lastAppUpdateNotificationTime = formattedDate
        }
    }

    func getLastNotificationDate(for type: NotificationType) -> Date? {
        let dateString: String
        switch type {
        case .softwareUpdate:
            dateString = appState.preferences.notifications.lastSoftwareUpdateNotificationTime
        case .rebootReminder:
            dateString = appState.preferences.notifications.lastRebootReminderNotificationTime
        case .generic:
            dateString = appState.preferences.notifications.lastGenericNotificationTime
        case .appUpdate:
            dateString = appState.preferences.notifications.lastAppUpdateNotificationTime
        }
        guard !dateString.isEmpty else { return nil }
        return ISO8601DateFormatter().date(from: dateString)
    }
}

func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if let error = error {
            Logger.shared.logError("Error requesting notification permissions: \(error.localizedDescription)")
        } else if granted {
            Logger.shared.logDebug("Notification permissions granted")
        } else {
            Logger.shared.logDebug("Notification permissions denied")
        }
    }
}

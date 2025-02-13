//
//  NotificationService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import UserNotifications
import SwiftUI

class NotificationService {
    private let appState: AppStateManager
    
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

    func sendNotification(
        message: String,
        buttonText: String? = nil,
        command: String? = nil,
        notificationType: NotificationType
    ) {
        guard appState.preferences.notificationInterval > 0 else {
            Logger.shared.logDebug("Notification interval set to 0, skipping notification")
            return
        }
        
        let imagePath = appState.preferences.notificationImage.isEmpty ? nil : appState.preferences.notificationImage

        if notificationType != .generic {
            if let lastDate = AppStorageHelper.shared.getLastNotificationDate(for: notificationType),
            Date().timeIntervalSince(lastDate) < TimeInterval(appState.preferences.notificationInterval * 3600) {
                Logger.shared.logDebug("Notification interval for \(notificationType) not reached, skipping notification")
                return
            }
        }

        let content = UNMutableNotificationContent()
        content.title = appState.preferences.notificationTitle
        content.body = message
        content.sound = .default
        content.userInfo = ["Command": command]
        content.categoryIdentifier = "ACTIONABLE"
        
        if let imagePath = imagePath, let tempURL = prepareImageForNotification(imagePath: imagePath) {
            do {
                let attachment = try UNNotificationAttachment(identifier: "image", url: tempURL, options: nil)
                content.attachments = [attachment]
            } catch {
                Logger.shared.logError("Failed to attach image: \(error.localizedDescription)")
            }
        }

        var actions: [UNNotificationAction] = []
        if let buttonText = buttonText, let command = command {
            let action = UNNotificationAction(
                identifier: "RUN_COMMAND",
                title: buttonText,
                options: [.foreground]
            )
            actions.append(action)
        }

        let category = UNNotificationCategory(
            identifier: "ACTIONABLE",
            actions: actions,
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.shared.logDebug("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                Logger.shared.logDebug("Notification sent: \(message)")
                AppStorageHelper.shared.setLastNotificationDate(Date(), for: notificationType)
            }
        }
    }
}

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == "RUN_COMMAND",
           let command = response.notification.request.content.userInfo["Command"] as? String {
            Logger.shared.logDebug("Notification button clicked, running command: \(command)")
            if command == "demote" {
                AppStateManager.shared.stopDemotionTimer()
                ElevationManager.shared.demotePrivileges { success in
                    if success {
                        Logger.shared.logDebug("Successfully demoted privileges")
                    } else {
                        Logger.shared.logError("Failed to demote privileges")
                    }
                }
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

class BadgeManager {
    static let shared = BadgeManager()
    private(set) var badgeCount = 0
    private let lock = NSLock()

    func incrementBadgeCount(count: Int) {
        lock.lock()
        badgeCount = count
        lock.unlock()
        updateBadge()
    }

    func currentBadgeCount() -> Int {
        lock.lock()
        let count = badgeCount
        lock.unlock()
        return count
    }

    private func updateBadge() {
        DispatchQueue.main.async {
            if self.badgeCount > 0 {
                let prefs = AppStateManager.shared.preferences
                let hasPendingUpdates = !prefs.hiddenCards.contains("PendingAppUpdates") && AppStateManager.shared.pendingUpdatesCount > 0
                let hasSoftwareUpdates = !prefs.hiddenActions.contains("SoftwareUpdates") && AppStateManager.shared.systemUpdateCache.count > 0
                if hasPendingUpdates || hasSoftwareUpdates {
                    NSApplication.shared.dockTile.showsApplicationBadge = true
                    NSApplication.shared.dockTile.badgeLabel = nil
                    NSApplication.shared.dockTile.badgeLabel = String(self.badgeCount)
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
}

enum NotificationType: String {
    case softwareUpdate
    case rebootReminder
    case appUpdate
    case generic
}


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
            appState.preferences.lastSoftwareUpdateNotificationTime = formattedDate
        case .rebootReminder:
            appState.preferences.lastRebootReminderNotificationTime = formattedDate
        case .generic:
            appState.preferences.lastGenericNotificationTime = formattedDate
        case .appUpdate:
            appState.preferences.lastAppUpdateNotificationTime = formattedDate
        }
    }

    func getLastNotificationDate(for type: NotificationType) -> Date? {
        let dateString: String
        switch type {
        case .softwareUpdate:
            dateString = appState.preferences.lastSoftwareUpdateNotificationTime
        case .rebootReminder:
            dateString = appState.preferences.lastRebootReminderNotificationTime
        case .generic:
            dateString = appState.preferences.lastGenericNotificationTime
        case .appUpdate:
            dateString = appState.preferences.lastAppUpdateNotificationTime
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

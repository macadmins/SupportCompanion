//
//  NotificationPreferences.swift
//  SupportCompanion
//

import Foundation
import SwiftUI

class NotificationPreferences: ObservableObject {
    // MARK: - Notification timestamps
    @AppStorage("LastSoftwareUpdateNotificationTime") var lastSoftwareUpdateNotificationTime: String = ""
    @AppStorage("LastRebootReminderNotificationTime") var lastRebootReminderNotificationTime: String = ""
    @AppStorage("LastGenericNotificationTime") var lastGenericNotificationTime: String = ""
    @AppStorage("LastAppUpdateNotificationTime") var lastAppUpdateNotificationTime: String = ""

    // MARK: - Notification content
    @AppStorage("NotificationTitle") var notificationTitle: String = "Support Companion"
    @AppStorage("NotificationInterval") var notificationInterval: Int = 4
    @AppStorage("NotifcationImage") var notificationImage: String = ""

    // MARK: - Software update notification
    @AppStorage("SoftwareUpdateNotificationButtonText") var softwareUpdateNotificationButtonText: String = Constants.Notifications.SoftwareUpdate.UpdateNotificationButtonText
    @AppStorage("SoftwareUpdateNotificationCommand") var softwareUpdateNotificationCommand: String = "open \(Constants.Panels.softwareUpdates)"
    @AppStorage("SoftwareUpdateNotificationMessage") var softwareUpdateNotificationMessage: String = Constants.Notifications.SoftwareUpdate.UpdateNotificationMessage

    // MARK: - App update notification
    @AppStorage("AppUpdateNotificationMessage") var appUpdateNotificationMessage: String = Constants.Notifications.AppUpdate.UpdateNotificationMessage
    @AppStorage("AppUpdateNotificationButtonText") var appUpdateNotificationButtonText: String = Constants.Notifications.AppUpdate.UpdateNotificationButtonText
    @AppStorage("AppUpdateNotificationCommand") var appUpdateNotificationCommand: String = ""

    // MARK: - Reboot reminder
    @AppStorage("RebootReminderDays") var rebootReminderDays: Int = 0
}

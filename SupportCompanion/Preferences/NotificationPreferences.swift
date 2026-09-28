//
//  NotificationPreferences.swift
//  SupportCompanion
//

import Foundation
import Observation

@MainActor
@Observable
class NotificationPreferences {
    // MARK: - Notification timestamps
    var lastSoftwareUpdateNotificationTime: String {
        get { DefaultsStore.value(forKey: "LastSoftwareUpdateNotificationTime", default: "") }
        set { DefaultsStore.set(newValue, forKey: "LastSoftwareUpdateNotificationTime") }
    }
    var lastRebootReminderNotificationTime: String {
        get { DefaultsStore.value(forKey: "LastRebootReminderNotificationTime", default: "") }
        set { DefaultsStore.set(newValue, forKey: "LastRebootReminderNotificationTime") }
    }
    var lastGenericNotificationTime: String {
        get { DefaultsStore.value(forKey: "LastGenericNotificationTime", default: "") }
        set { DefaultsStore.set(newValue, forKey: "LastGenericNotificationTime") }
    }
    var lastAppUpdateNotificationTime: String {
        get { DefaultsStore.value(forKey: "LastAppUpdateNotificationTime", default: "") }
        set { DefaultsStore.set(newValue, forKey: "LastAppUpdateNotificationTime") }
    }

    // MARK: - Notification content
    var notificationTitle: String {
        get { DefaultsStore.value(forKey: "NotificationTitle", default: "Support Companion") }
        set { DefaultsStore.set(newValue, forKey: "NotificationTitle") }
    }
    var notificationInterval: Int {
        get { DefaultsStore.value(forKey: "NotificationInterval", default: 4) }
        set { DefaultsStore.set(newValue, forKey: "NotificationInterval") }
    }
    var notificationImage: String {
        get { DefaultsStore.value(forKey: "NotificationImage", default: "") }
        set { DefaultsStore.set(newValue, forKey: "NotificationImage") }
    }

    // MARK: - Software update notification
    var softwareUpdateNotificationButtonText: String {
        get { DefaultsStore.value(forKey: "SoftwareUpdateNotificationButtonText", default: Constants.Notifications.SoftwareUpdate.UpdateNotificationButtonText) }
        set { DefaultsStore.set(newValue, forKey: "SoftwareUpdateNotificationButtonText") }
    }
    var softwareUpdateNotificationCommand: String {
        get { DefaultsStore.value(forKey: "SoftwareUpdateNotificationCommand", default: "open \(Constants.Panels.softwareUpdates)") }
        set { DefaultsStore.set(newValue, forKey: "SoftwareUpdateNotificationCommand") }
    }
    var softwareUpdateNotificationMessage: String {
        get { DefaultsStore.value(forKey: "SoftwareUpdateNotificationMessage", default: Constants.Notifications.SoftwareUpdate.UpdateNotificationMessage) }
        set { DefaultsStore.set(newValue, forKey: "SoftwareUpdateNotificationMessage") }
    }

    // MARK: - App update notification
    var appUpdateNotificationMessage: String {
        get { DefaultsStore.value(forKey: "AppUpdateNotificationMessage", default: Constants.Notifications.AppUpdate.UpdateNotificationMessage) }
        set { DefaultsStore.set(newValue, forKey: "AppUpdateNotificationMessage") }
    }
    var appUpdateNotificationButtonText: String {
        get { DefaultsStore.value(forKey: "AppUpdateNotificationButtonText", default: Constants.Notifications.AppUpdate.UpdateNotificationButtonText) }
        set { DefaultsStore.set(newValue, forKey: "AppUpdateNotificationButtonText") }
    }
    var appUpdateNotificationCommand: String {
        get { DefaultsStore.value(forKey: "AppUpdateNotificationCommand", default: "") }
        set { DefaultsStore.set(newValue, forKey: "AppUpdateNotificationCommand") }
    }

    // MARK: - Reboot reminder
    var rebootReminderDays: Int {
        get { DefaultsStore.value(forKey: "RebootReminderDays", default: 0) }
        set { DefaultsStore.set(newValue, forKey: "RebootReminderDays") }
    }
}

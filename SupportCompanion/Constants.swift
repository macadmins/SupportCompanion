//
//  Constants.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation

enum Constants {
    
    enum Support {
        enum Titles {
            static let support = String(localized: "Support.Support", defaultValue: "Support", comment: "Support title")
        }
        enum Labels {
            static let phone = String(localized: "Support.Phone", defaultValue: "Phone:", comment: "Phone number")
            static let email = String(localized: "Support.Email", defaultValue: "Email:", comment: "Email address")
        }
        enum Keys {
            static let phone = "SupportPhone"
            static let email = "SupportEmail"
        }
    }
    
    enum modes {
        static let munki = "Munki"
        static let intune = "Intune"
        static let systemProfiler = "SystemProfiler"
		static let jamf = "Jamf"
    }
    
    enum TrayMenu {
        static let openApp = String(localized: "TrayMenu.OpenApp", defaultValue: "Open Support Companion", comment: "Open the app")
        static let quitApp = String(localized: "TrayMenu.QuitApp", defaultValue: "Quit", comment: "Quit the app")
    }
    
    enum General {
        static let days = String(localized: "General.Days", defaultValue: "Days", comment: "Number of days")
        static let day = String(localized: "General.Day", defaultValue: "Day", comment: "Number of day")
        static let dayAgo = String(localized: "General.DayAgo", defaultValue: "Day Ago", comment: "Number of day ago")
        static let daysAgo = String(localized: "General.DaysAgo", defaultValue: "Days Ago", comment: "Number of days ago")
        static let hours = String(localized: "General.Hours", defaultValue: "Hours", comment: "Number of hours")
        static let hour = String(localized: "General.Hour", defaultValue: "Hour", comment: "Number of hour")
        static let minute = String(localized: "General.Minute", defaultValue: "Minute", comment: "Number of minute")
        static let minutes = String(localized: "General.Minutes", defaultValue: "Minutes", comment: "Number of minutes")
        static let second = String(localized: "General.Second", defaultValue: "Second", comment: "Number of second")
        static let seconds = String(localized: "General.Seconds", defaultValue: "Seconds", comment: "Number of seconds")
        static let manage = String(localized: "General.Manage", defaultValue: "Manage", comment: "Manage")
        static let close = String(localized: "General.Close", defaultValue: "Close", comment: "Close")
        static let elevate = String(localized: "General.Elevate", defaultValue: "Elevate", comment: "Elevate")
        static let demote: String = String(localized: "General.Demote", defaultValue: "Demote", comment: "Demote")
    }
    
    enum AppPaths {
        static let companyPortal = "/Applications/Company Portal.app"
        static let MSC = "/Applications/Managed Software Center.app"
        static let MSCUpdates = "munki://updates.html"
		static let selfService = "/Applications/Self Service+.app"
    }
    
    enum Paths {
        static let tempArchivePath = "/tmp/supportcompanion_logs.zip"
		static let jamfSelfServiceData = "~/Library/Application Support/osx-self-service.Self-Service.resources/CocoaAppCD.storedata"
    }
    
    enum Panels {
        static let storage = "x-apple.systempreferences:com.apple.settings.Storage"
        static let softwareUpdates = "x-apple.systempreferences:com.apple.preferences.softwareupdate"
        static let users = "x-apple.systempreferences:com.apple.preferences.users"
    }
    
    enum ToolTips {
        static let deviceInfoCopy = String(localized: "ToolTip.DeviceInfoCopy", defaultValue: "Copy device information to clipboard", comment: "Tooltip text when copying device information to clipboard")
        static let openStoragePanel = String(localized: "ToolTip.OpenStoragePanel", defaultValue: "Open storage panel", comment: "Tooltip text when opening the storage panel")
        static let deviceLastRebooted = String(localized: "ToolTip.DeviceLastRebooted", defaultValue: "Regularly rebooting your device can enhance its performance and longevity by clearing temporary files and freeing up system resources.", comment: "Tooltip text when showing reboot information")
    }
    
    enum Notifications {
        enum SoftwareUpdate {
            static let UpdateNotificationMessage = String(localized: "Notification.UpdateAvailable", defaultValue: "Software Updates Available. Please update your device to the latest version.", comment: "Notification message when an update is available")
            static let UpdateNotificationButtonText = String(localized: "Notification.UpdateNow", defaultValue: "Update Now 🚀", comment: "Notification button text when an update is available")
        }
        
        enum AppUpdate {
            static let UpdateNotificationMessage = String(localized: "Notification.AppUpdateAvailable", defaultValue: "App Updates Available. Please update your apps to the latest version.", comment: "Notification message when an update is available")
            static let UpdateNotificationButtonText = String(localized: "Notification.UpdateNow", defaultValue: "Update Now 🚀", comment: "Notification button text when an update is available")
        }

        enum Elevation {
            static let ElevationStartedMessage = String(localized: "Notification.ElevationStarted", defaultValue: "Privliged session started. You will be demoted in", comment: "Notification message when an elevation is started")
            static let ElevationHalfwayMessage = String(localized: "Notification.ElevationHalfway", defaultValue: "Your elevated privileges will be demoted in", comment: "Notification message when half the time has passed")
            static let ElevationDemotedMessage = String(localized: "Notification.ElevationDemoted", defaultValue: "Your elevated privileges have been demoted.", comment: "Notification message when the elevation is demoted")
        }

        enum Reboot {
            static let RebootMessage = String(localized: "Notification.RebootReminder", defaultValue: "Your device was last restarted %lld %@ ago. Please reboot your device to ensure optimal performance and security.", comment: "Notification message reminding the user to reboot their device")
        }
    }
    
    enum Errors {
        static let noInternetConnection = String(localized: "Error.NoInternetConnection", defaultValue: "No internet connection is available.", comment: "Error message when no internet connection is available")
        static let invalidRealmSSO = String(localized: "Error.InvalidRealm", defaultValue: "Invalid SSO REALM detected.", comment: "Error message when the realm is invalid")
        static let commandFailedSSO = String(localized: "Error.CommandFailed", defaultValue: "Failed to execute the SSO command.", comment: "Error message when a command failed")
    }
    
    enum Titles {
        static let saveLogs = String(localized: "Title.SaveLogs", defaultValue: "Save Logs", comment: "Title for save logs dialog")
    }
    
    enum Cards {
        static let storage = "Storage"
        static let actions = "Actions"
        static let evergreen = "Evergreen"
        static let deviceInfo = "DeviceInformation"
        static let deviceManagement = "DeviceManagement"
        static let appPatchProgress = "ApplicationInstallProgress"
        static let battery = "Battery"
        static let pendingAppUpdates = "PendingAppUpdates"
    }
    
    enum CardTitle {
        static let storage = String(localized: "Card.StorageTitle", defaultValue: "Storage", comment: "Title for storage card")
        static let actions = String(localized: "Card.ActionsTitle", defaultValue: "Actions", comment: "Title for actions card")
        static let evergreen = String(localized: "Card.EvergreenTitle", defaultValue: "Evergreen", comment: "Title for evergreen card")
        static let deviceInfo = String(localized: "Card.DeviceInfoTitle", defaultValue: "Device Information", comment: "Title for device info card")
        static let deviceManagement = String(localized: "Card.DeviceManagementTitle", defaultValue: "Device Management", comment: "Title for device management card")
        static let appPatchProgress = String(localized: "Card.AppPatchProgressTitle", defaultValue: "Application Patching Progress", comment: "Title for app patch progress card")
        static let battery = String(localized: "Card.BatteryTitle", defaultValue: "Battery", comment: "Title for battery card")
        static let kerberosSSO = String(localized: "Card.KerberosSSOTitle", defaultValue: "Kerberos Single Sign On", comment: "Title for kerberos sso card")
        static let platformSSO = String(localized: "Card.PlatformSSOTitle", defaultValue: "Platform Single Sign On", comment: "Title for platform sso card")
        static let userInfo = String(localized: "Card.UserInfoTitle", defaultValue: "User Information", comment: "Title for user info card")
        static let pendingUpdates = String(localized: "Card.PendingUpdatesTitle", defaultValue: "Pending Updates", comment: "Title for pending updates card")
        static let installedApps = String(localized: "Card.InstalledAppsTitle", defaultValue: "Installed Applications", comment: "Title for installed apps card")
        static let privileges = String(localized: "Card.PrivilegesTitle", defaultValue: "Privileges", comment: "Title for privileges card")
    }
    
    enum RebootModal {
        static let title = String(localized: "Modal.RebootTitle", defaultValue: "Reboot Scheduled", comment: "Title for reboot modal")
        static let countdown = 60
        static let message = String(localized: "Modal.RebootMessage", defaultValue: "Your system will reboot soon.", comment: "Message for reboot modal")
    }
    
    enum Actions {
        static let reboot = String(localized: "Action.Reboot", defaultValue: "Reboot", comment: "Label for reboot action")
        static let changePassword = String(localized: "Action.ChangePassword", defaultValue: "Change Password", comment: "Label for change password action")
        static let gatherLogs = String(localized: "Action.GatherLogs", defaultValue: "Gather Logs", comment: "Label for gather logs action")
        static let restartIntuneAgent = String(localized: "Action.RestartIntuneAgent", defaultValue: "Restart Intune Agent", comment: "Label for restart Intune agent action")
        static let openManagementApp = String(localized: "Action.OpenManagementApp", defaultValue: "Open Management App", comment: "Label for open management app action")
        static let softwareUpdate = String(localized: "Action.SoftwareUpdate", defaultValue: "Software Update", comment: "Label for software update action")
        static let getSupport = String(localized: "Action.GetSupport", defaultValue: "Get Support", comment: "Label for get support action")

        enum HideStrings {
            static let changePassword = "ChangePassword"
            static let gatherLogs = "GatherLogs"
            static let restartIntuneAgent = "RestartIntuneAgent"
            static let openManagementApp = "OpenManagementApp"
            static let softwareUpdate = "SoftwareUpdates"
            static let getSupport = "GetSupport"
            static let reboot = "Reboot"
        }
    }
    
    enum ToastMessages {
        enum SuccessMessages {
            static let gatherLogsSuccess = String(localized: "GatherLogs.Success", defaultValue: "Logs gathered successfully.", comment: "Message for successfully gathered logs")
        }
        enum FailureMessages {
            static let changePasswordSSOEFailure = String(localized: "ChangePasswordSSOE.Failure", defaultValue: "SSO Realm could not be fetched.", comment: "Failure message if REALM cannot be fetched")
        }
        enum InfoMessages {
            static let changePasswordSSOEInfo = String(localized: "ChangePasswordSSOE.Info", defaultValue: "Cannot reach %@. Ensure VPN or corporate network is connected.", comment: "Info message if REALM cannot be reached")
            static let gatherLogsInfo = String(localized: "GatherLogs.Info", defaultValue: "Gather logs was cancelled", comment: "Info message for gathering logs")
        }
    }
    
    enum Navigation {
        static let home = String(localized: "Nav.Home", defaultValue: "Home", comment: "Label for home navigation")
        static let knowledgeBase = String(localized: "Nav.KnowledgeBase", defaultValue: "Knowledge Base", comment: "Label for knowledge base navigation")
        static let identity = String(localized: "Nav.Identity", defaultValue: "Identity", comment: "Label for identity navigation")
        static let apps = String(localized: "Nav.Apps", defaultValue: "Apps", comment: "Label for apps navigation")
        static let selfService = String(localized: "Nav.SelfService", defaultValue: "Self Service", comment: "Label for self service navigation")
    }
    
    enum DeviceInfo {
        enum Labels {
            static let hostName = String(localized: "DeviceInfo.HostName", defaultValue: "Host Name:", comment: "Label for host name")
            static let model = String(localized: "DeviceInfo.Model", defaultValue: "Model:", comment: "Label for model")
            static let cpuType = String(localized: "DeviceInfo.CpuType", defaultValue: "Processor:", comment: "Label for CPU type")
            static let ram = String(localized: "DeviceInfo.Ram", defaultValue: "Memory:", comment: "Label for RAM")
            static let osVersion = String(localized: "DeviceInfo.OsVersion", defaultValue: "OS Version:", comment: "Label for OS version")
            static let osBuild = String(localized: "DeviceInfo.OsBuild", defaultValue: "OS Build:", comment: "Label for OS build")
            static let lastRestart = String(localized: "DeviceInfo.LastRestart", defaultValue: "Last Restart:", comment: "Label for last restart")
            static let ipAddress = String(localized: "DeviceInfo.IpAddress", defaultValue: "IP Address:", comment: "Label for IP address")
            static let serialNumber = String(localized: "DeviceInfo.SerialNumber", defaultValue: "Serial Number:", comment: "Label for serial number")
        }
        enum Categories {
            static let hardwareSpecs = String(localized: "DeviceInfo.HardwareSpecs", defaultValue: "Hardware Specifications", comment: "Category for hardware specs")
            static let networkInfo = String(localized: "DeviceInfo.NetworkInfo", defaultValue: "Network Information", comment: "Category for network info")
            static let systemInfo = String(localized: "DeviceInfo.SystemInfo", defaultValue: "System Information", comment: "Category for system info")
        }
        
        enum Keys {
            static let hostName = "HostName"
            static let processor = "Processor"
            static let memory = "Memory"
            static let osVersion = "OSVersion"
            static let osBuild = "OSBuild"
            static let lastRestart = "LastRestart"
            static let ipAddress = "IPAddress"
            static let model = "Model"
            static let serialNumber = "SerialNumber"
        }
    }
    
    enum KerberosSSO {
        enum Labels {
            static let exipiryDays = String(localized: "KerberosSSO.ExipiryDays", defaultValue: "AD Password Expiry:", comment: "Label for the number of days before the password expires")
            static let lastSSOPasswordChangeDays = String(localized: "KerberosSSO.LastSSOPasswordChangeDays", defaultValue: "Last AD Password Change:", comment: "Label for the last time the SSO password was changed")
            static let lastLocalPasswordChangeDays = String(localized: "KerberosSSO.LastLocalPasswordChangeDays", defaultValue: "Last Local Password Change:", comment: "Label for the last time the local password was changed")
            static let kerberosSSOUsername = String(localized: "KerberosSSO.Username", defaultValue: "Username:", comment: "Label for the username")
        }
        
        enum Keys {
            static let expiryDays = "ExpiryDays"
            static let lastSSOPasswordChangeDays = "LastSSOPasswordChangeDays"
            static let lastLocalPasswordChangeDays = "LastLocalPasswordChangeDays"
            static let kerberosSSOUsername = "Username"
            static let realm = "Realm"
        }
    }
    
    enum PlatformSSO {
        enum Labels {
            static let loginFrequency = String(localized: "PlatformSSO.LoginFrequency", defaultValue: "Login Frequency:", comment: "Label for the login frequency")
            static let loginType = String(localized: "PlatformSSO.LoginType", defaultValue: "Login Type:", comment: "Label for the login type")
            static let newUserAuthorizationMode = String(localized: "PlatformSSO.NewUserAuthorizationMode", defaultValue: "New User Authorization Mode:", comment: "Label for the new user authorization mode")
            static let registrationCompleted = String(localized: "PlatformSSO.RegistrationCompleted", defaultValue: "Registration Completed:", comment: "Label for the registration completion status")
            static let sdkVersionString = String(localized: "PlatformSSO.SDKVersionString", defaultValue: "SDK Version:", comment: "Label for the SDK version string")
            static let sharedDeviceKeys = String(localized: "PlatformSSO.SharedDeviceKeys", defaultValue: "Shared Device Keys:", comment: "Label for the shared device keys")
            static let userAuthorizationMode = String(localized: "PlatformSSO.UserAuthorizationMode", defaultValue: "User Authorization Mode:", comment: "Label for the user authorization mode")
        }
        
        enum Keys {
            static let loginFrequency = "LoginFrequency"
            static let loginType = "LoginType"
            static let newUserAuthorizationMode = "NewUserAuthorizationMode"
            static let registrationCompleted = "RegistrationCompleted"
            static let sdkVersionString = "SDKVersionString"
            static let sharedDeviceKeys = "SharedDeviceKeys"
            static let userAuthorizationMode = "UserAuthorizationMode"
        }
    }
    
    enum Battery {
        enum Labels {
            static let health = String(localized: "Battery.Health", defaultValue: "Health:", comment: "Label for the battery health")
            static let cycleCount = String(localized: "Battery.CycleCount", defaultValue: "Cycle Count:", comment: "Label for the battery cycle count")
            static let temperature = String(localized: "Battery.Temperature", defaultValue: "Temperature:", comment: "Label for the battery temperature")
            static let isCharging = String(localized: "Battery.IsCharging", defaultValue: "Is Charging:", comment: "Label for the battery charging status")
            static let timeToFull = String(localized: "Battery.TimeToFull", defaultValue: "Time to Full:", comment: "Label for the battery time to full")
            static let charging = String(localized: "Battery.Charging", defaultValue: "Charging", comment: "Label for the battery charging status")
            static let notCharging = String(localized: "Battery.NotCharging", defaultValue: "Not Charging", comment: "Label for the battery charging status")
            static let usage = String(localized: "Battery.Usage", defaultValue: "Usage:", comment: "Label for the battery usage")
        }
        
        enum Keys {
            static let health = "Health"
            static let cycleCount = "CycleCount"
            static let temperature = "Temperature"
            static let isCharging = "IsCharging"
            static let timeToFull = "TimeToFull"
        }
    }
    
    enum MDM {
        enum Labels {
            static let enrolled = String(localized: "MDM.Enrolled", defaultValue: "Enrolled:", comment: "Label for the MDM enrollment status")
            static let enrolledDate = String(localized: "MDM.EnrolledDate", defaultValue: "Enrolled Date:", comment: "Label for the MDM enrollment date")
        }
        
        enum Keys {
            static let enrolled = "Enrolled"
            static let enrolledDate = "EnrolledDate"
        }
    }
    
    enum Storage {
        enum Labels {
            static let name = String(localized: "Storage.Name", defaultValue: "Name:", comment: "Label for the storage name")
        }
        
        enum Keys {
            static let name = "StorageName"
            static let fileVault = "FileVault"
            static let usage = "Usage"
        }
    }
    
    enum UserInfo {
        enum Labels {
            static let username = String(localized: "UserInfo.Username", defaultValue: "Username:", comment: "Label for the username")
            static let name = String(localized: "UserInfo.Name", defaultValue: "Name:", comment: "Label for the name")
            static let homeDir = String(localized: "UserInfo.HomeDir", defaultValue: "Home Directory:", comment: "Label for the home directory")
            static let shell = String(localized: "UserInfo.Shell", defaultValue: "Shell:", comment: "Label for the shell")
            static let isAdmin = String(localized: "UserInfo.IsAdmin", defaultValue: "Is Admin:", comment: "Label for the is admin status")
        }
        
        enum Keys {
            static let username = "Login"
            static let name = "Name"
            static let homeDir = "HomeDirectory"
            static let shell = "Shell"
            static let isAdmin = "IsAdmin"
        }
    }
    
    enum TabelHeaders {
        static let name = String(localized: "TabelHeaders.Name", defaultValue: "Name", comment: "Header for the name column")
        static let version = String(localized: "TabelHeaders.Version", defaultValue: "Version", comment: "Header for the version column")
        static let action = String(localized: "TabelHeaders.Action", defaultValue: "Action", comment: "Header for the action column")
    }
}

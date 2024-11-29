# [#SupportCompanion](https://macadmins.slack.com/archives/C075C6ZFAJH)

<img width="256" alt="AppIcon" src="https://github.com/user-attachments/assets/8d9dea5d-230d-4c77-9b11-3e3f39e63f5f">

## Description

Support Companion is a macOS helper application, designed to empower end-users by providing them with
quick and easy access to crucial information and actions. This application is built to streamline a variety of
tasks, eliminating the need for extensive searching and complex navigation. Support Companion is equipped with a range
of features that enhance user productivity.

It integrates with Munki and Intune for application information and updates, providing a unified platform for managing these services. Users can view system information
such as macOS version, model, and serial number at a glance, and perform actions such as changing passwords, rebooting,
and more with just a few clicks.

This initial version relies on Munki and/or Intune for application information and updates. If you are
not using Munki or Intune, this app may not provide as detailed information at the moment.

If there are wishes to add other MDM specific actions and information, please let me know. I am open to
adding more MDM providers in the future if there is a demand for it.
I am only able to test with Intune, so if you have another MDM provider, I would appreciate your help in testing.

## Features

- **Actions**: Perform actions such as Change Password, Kill Intune MDM Agent, gather logs, reboot and more.
- **System Information**: Quickly view system information such as macOS version, model, serial number and last boot
  time.
- **Evergreen**: See which Munki catalogs the devices is a member of (requires a local device manifest with the SN as
  name).
- **Battery**: View battery information such as cycle count and health.
- **MDM**: View MDM information such as enrollment status and enrollment date.
- **Disk**: View disk information such as disk space and FileVault status.
- **Application Patching Progress**: View the progress of patching applications.
- **Pending Updates**: View pending updates for applications.
- **Applications**: View installed applications and their versions.
- **Identity**: View the current user's profile information and Kerberos SSO or Platform SSO information.
- **Desktop Info**: Show information on the desktop such as device name, serial number, macOS version, and IP address.
- **Custom Cards**: Add custom cards to the Home view, this allows for displaying information specific to your
  organization.
- **Self Service**: Shows all actions in the app configured in the MDM profile. This allows for a self-service
  experience for the user using the UI and not only the menu bar icon.
- **Company Portal**: If mode is set to `Intune` or if Company Portal is installed, a web view of Company Portal will show in the navigation.
- **Knowledge Base**: If a knowledge base URL is configured, a menu item for a web view will show up.
## Localization

The app is localized to `Swedish`, `Norwegian`, `French` and `German`. The app will display in the user's preferred language if it is set to one of these languages in macOS. If the user's preferred language is not one of these, the app will default to English.

Contributions to other languages are welcome!

## Installation

1. Obtain the latest PKG installer from [releases](https://github.com/almenscorner/SupportCompanion/releases).
2. Run the PKG installer.
3. Optional
    - Install the Launch Agent package attached to the release to automatically start and keep the app running.

## Installed files

The app is installed in the `/Applications` folder and the following files and folders are installed:
- `/Applications/SupportCompanion.app` - The app bundle
- `/Library/LaunchDaemons/com.github.macadmins.SupportCompanion.helper.plist` - LaunchDaemon for the privileged helper
- `/Library/PrivilegedHelperTools/com.github.macadmins.SupportCompanion.helper` - Helper tool to run privileged commands such as resart Intune Agent

## Uninstallation

An uninstaller script is included in the app bundle. The script can be found in the following location:
`/Applications/SupportCompanion.app/Contents/Resources/Uninstall.sh`

## About the Launch Agent
The Launch Agent provided as a signed, notarized and stapled package will, if installed and loaded:
- Start the app if it is not running
- Start the app again if quit by the user
- Start the app on login

This Launch Agent is optional and you are free to create your own Launch Agent if you prefer.

## About the suite package
The suite package is a signed, notarized and stapled package that contains the app and the Launch Agent package. 
This package is provided for convenience and can be used to install the app and the Launch Agent at the same time.

## AutoPkg
A recipe for AutoPkg is available [here](https://github.com/autopkg/almenscorner-recipes/tree/main/SupportCompanion).

## A note on icons
When configuring icons for custom widgets or actions, the icon name should be a SF Symbols name. For example `questionmark`.

## Using the app

When the app is started, a menu bar icon will appear. Clicking the icon will show available actions to take like
opening the app. The dock icon will only be shown when the main window is active.
This is to keep the app out of the way and not clutter the dock and make it easy for admins to start the app from a
terminal or script without showing the app to the end-user. Initializing the app this way sends notifications to the
user if they have available software updates for example.

## Troubleshooting
Logs can be viewed by running the following command in the terminal:
`log stream --debug --info --predicate 'subsystem contains "com.github.macadmins.SupportCompanion"'`

Or by searching for `subsystem: com.github.macadmins.SupportCompanion` in the Console app.

## Configuration

Many aspects of the app can be configured using MDM profiles, the folloing keys are available:
| Key | Type | Default | Required | Description |
| --- | --- | --- | --- | --- |
| `BrandName` | String | None | False | Configures the brand name shown in the menu |
| `AccentColor` | String | User primary accent color | False | Configures the brand color shown in the app, specify in hex format |
| `BrandLogo` | String | None | False | Configures the brand logo shown in the apps side menu. Specify a base64 string |
| `SupportPageUrl` | String | None | False | Configures the URL to open when the user clicks on the Get Support button |
| `ChangePasswordUrl` | String | None | False | Configures the URL to open when the user clicks on the Change Password button |
| `ChangePasswordMode` | String | local | False | Configures the mode for the Change Password button, available modes are: `local`, `SSOExtension`, `url` |
| `SupportEmail` | String | None | False | Configures the email address shown when the user clicks on the Support Info button |
| `SupportPhone` | String | None | False | Configures the phone number shown when the user clicks on the Support Info button |
| `HiddenCards` | Array | None | False | Configures which widgets to hide, available widgets are: `DeviceInformation`, `Evergreen`, `Battery`, `Actions`, `ApplicationInstallProgress`, `Storage`, `DeviceManagement`, `PendingAppUpdates` |
| `HiddenActions` | Array | None | False | Configures which actions to hide, available actions are: `ChangePassword`, `Reboot`, `OpenManagementApp`, `GetSupport`, `GatherLogs`, `SoftwareUpdates`, `RestartIntuneAgent` |
| `NotificationInterval` | Integer | 4 | False | Configures the interval for notifications in hours for Application Updates and Software Updates notifications. Setting to 0 disables notifications |
| `NotificationTitle` | String | Support Companion | False | Configures the title for notifications |
| `NotificationImage` | String | None | False | Configures an image to add to notifications. Path should be specified |
| `SoftwareUpdateNotificationMessage` | String | You have software updates available. Take action now! \ud83c\udf89 | False | Configures the message for notifications for Software Updates notifications |
| `SoftwareUpdateNotificationButtonText` | String | Details \ud83d\udc40 | False | Configures the button text for notifications for Software Updates notifications |
| `AppUpdateNotificationMessage` | String | You have app updates available. Take action now! \ud83c\udf89 | False | Configures the message for notifications for App Updates notifications |
| `AppUpdateNotificationButtonText` | String | Details \ud83d\udc40 | False | Configures the button text for notifications for App Updates notifications |
| `Mode` | Bool | Dynamic | False | Configures the app to show application info for either Munki, Intune or to use System profiler for app info. The app tries to dynamically detect which mode to use. See table below. |
| `LogFolders` | Array | /Library/Logs/Microsoft | False | Configures the log folders to gather logs from. Only used when gathering logs. |
| `Actions` | Array | None | False | Configures custom actions to add to the tray menu and in Self Service view. If `Description` is configured it will show in the Self Service view and if `IsPrivileged` is set to `true` the action will be run by the privileged helper. See example below. |
| `ShowDesktopInfo` | Bool | False | False | Configures whether to show information on the desktop. |
| `DesktopPosition` | String | LowerRight | False | Configures the position of the desktop info, available positions are: `UpperLeft`, `UpperRight`, `BottomLeft`, `BottomRight` |
| `DesktopInfoLevel` | Integer | 4 | False | Configures the level of information to show on the desktop, available levels are: `1`, `2`, `3`, `4`, `5` |
| `DesktopInfoHideItems` | Array | None | False | Use this array to determine which information to hide. Available items are: `HostName`, `Model`, `SerialNumber`, `Processor`, `IPAddress`, `Memory`, `OSBuild`, `OSVersion`, `LastRestart`, `FileVault`, `StorageName`, `SupportPhone`, `SupportEmail` |
| `DesktopInfoBackgroundOpacity` | Real | 0.001 | False | Configures the background opacity for the desktop info. Configure a value between 1.0 - 0.1 |
| `DesktopInfoFontSize` | Integer | 14 | False | Configures the font size for the desktop info. |
| `CustomCardsPath` | String | None | False | Configures a path to a JSON file containing custom widgets to show on the Home view. |
| `KnowledgeBaseUrl` | String | None | False | If configured, a menu item "Knowledge base" will show up where the user can browse the page from the UI. |

### Example Configuration

The app will try to auto detect the `Mode` it should use. The mode will be set based on the following conditions:

- Managed Software Center is installed -> Mode = Munki
- Managed Software Center is installed and Company Portal is installed -> Mode = Munki
- Only Company Portal is installed -> Mode = Intune
- None of Managed Software Center or Company Portal is installed -> Mode = SystemProfiler

It can also be configured manually in the profile with the `Mode` key.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadDisplayName</key>
            <string>SupportCompanion</string>
            <key>PayloadIdentifier</key>
            <string>SupportCompanion.9C1EF466-BFEC-462F-930E-38BB9965B21F</string>
            <key>PayloadType</key>
            <string>com.github.macadmins.SupportCompanion</string>
            <key>PayloadUUID</key>
            <string>9C1EF466-BFEC-462F-930E-38BB9965B21F</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>BrandName</key>
            <string>AwesomeCorp</string>
            <key>HiddenCards</key>
            <array>
                <string>Evergreen</string>
            </array>
            <key>Actions</key>
            <array>
                <dict>
                    <key>Command</key>
                    <string>killall pboard</string>
                    <key>Icon</key>
                    <string>document.on.document.fill</string>
                    <key>Name</key>
                    <string>Restart clipboard</string>
                    <key>Description</key>
                    <string>Restarts pasteborad, useful if copy&amp;Paste is not working.</string>
                </dict>
                <dict>
                    <key>Command</key>
                    <string>defaults write com.apple.finder AppleShowAllFiles YES &amp;&amp; pkill Finder</string>
                    <key>Icon</key>
                    <string>eye.fill</string>
                    <key>Name</key>
                    <string>Show hidden files</string>
                    <key>Description</key>
                    <string>Shows hidden files in Finder. Will restart Finder once initiated.</string>
                </dict>
                <dict>
                    <key>Command</key>
                    <string>networksetup -setairportpower en0 off &amp;&amp; sleep 3 &amp;&amp; networksetup -setairportpower en0 on</string>
                    <key>Icon</key>
                    <string>wifi</string>
                    <key>Name</key>
                    <string>Restart WiFi</string>
                    <key>Description</key>
                    <string>Restarts the WiFi interface to resolve connectivity issues, such as slow speeds, dropped connections, or inability to connect to networks. This action can help refresh the network adapter and clear temporary issues without needing to restart the entire system.</string>
                </dict>
                <dict>
                    <key>Command</key>
                    <string>killall IntuneMdmAgent</string>
                    <key>Name</key>
                    <string>Restart Intune Agent</string>
                    <key>Icon</key>
                    <string>app</string>
                    <key>IsPrivileged</key>
                    <true/>
                    <key>Description</key>
                    <string>Restarts Intune MDM Agent. Useful if troubleshooting scripts or app installs from Intune.</string>
                </dict>
            </array>
            <key>LogFolders</key>
            <array>
                <string>/Library/Logs</string>
            </array>
            <key>DesktopInfoBackgroundOpacity</key>
            <real>0.3</real>
            <key>SupportPhone</key>
            <string>111-222-333</string>
            <key>SupportEmail</key>
            <string>support@awesomecorp.io</string>
            <key>DesktopInfoLevel</key>
            <integer>5</integer>
            <key>KnowledgeBaseUrl</key>
            <string>https://github.com/macadmins/supportcompanion</string>
            <key>DesktopInfoHideItems</key>
            <array>
                <string>SupportPhone</string>
            </array>
        </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>FirstApp</string>
    <key>PayloadIdentifier</key>
    <string>SC.A2283B66-D43C-48FF-BD1D-CE0EBB4CCA22</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>A2283B66-D43C-48FF-BD1D-CE0EBB4CCA22</string>
    <key>PayloadVersion</key>
    <integer>1</integer>
</dict>
</plist>

```

## Overview

### Home
![SCHome](https://github.com/almenscorner/SupportCompanion/assets/78877636/d908bb6a-d7ed-42a6-a5d1-5f500ea24a9c)
### Apps
![SCApps](https://github.com/almenscorner/SupportCompanion/assets/78877636/b63afaf6-e76a-4412-9a54-1af252e4f9b1)
### Identity
![SCIdentity](https://github.com/almenscorner/SupportCompanion/assets/78877636/c88849fb-3092-47f4-99a2-69c6cd8f9923)
### Support Info
![SCSupportInfo](https://github.com/almenscorner/SupportCompanion/assets/78877636/58ea4438-3de7-46d7-9f67-9de8c6e01a46)
### Gather logs
![SCLogs102](https://github.com/almenscorner/SupportCompanion/assets/78877636/8cdc3405-8268-4ac8-9210-fd0d5b8c1b85)
### Desktop Info
![SCNotification](https://github.com/macadmins/SupportCompanion/assets/78877636/9352c18b-c0a9-496e-8c0c-2c45805edbbb)
### Notifications
![SCNotification](https://github.com/almenscorner/SupportCompanion/assets/78877636/414a7d55-2925-4312-bd9c-9f11ac450e23)

## Credits

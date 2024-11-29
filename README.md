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
- **Custom Widgets**: Add custom widgets to the Home view, this allows for displaying information specific to your
  organization.
- **Self Service**: Shows all actions in the app configured in the MDM profile. This allows for a self-service
  experience for the user using the UI and not only the menu bar icon.
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
| `HiddenCards` | Array | None | False | Configures which widgets to hide, available widgets are: `DeviceInfo`, `MunkiPendingApps`, `MunkiUpdates`, `IntunePendingApps`, `IntuneUpdates`, `Storage`, `MdmStatus`, `Actions`, `Battery`, `EvergreenInfo` |
| `HiddenActions` | Array | None | False | Configures which actions to hide, available actions are: `Support`, `ManagedSoftwareCenter`, `ChangePassword`, `Reboot`, `KillAgent`, `SoftwareUpdates`, `GatherLogs` |
| `NotificationInterval` | Integer | 4 | False | Configures the interval for notifications in hours for Application Updates and Software Updates notifications. Setting to 0 disables notifications |
| `NotificationTitle` | String | Support Companion | False | Configures the title for notifications |
| `NotificationImage` | String | None | False | Configures an image to add to notifications. Path should be specified |
| `SoftwareUpdateNotificationMessage` | String | You have software updates available. Take action now! \ud83c\udf89 | False | Configures the message for notifications for Software Updates notifications |
| `SoftwareUpdateNotificationButtonText` | String | Details \ud83d\udc40 | False | Configures the button text for notifications for Software Updates notifications |
| `AppUpdateNotificationMessage` | String | You have app updates available. Take action now! \ud83c\udf89 | False | Configures the message for notifications for App Updates notifications |
| `AppUpdateNotificationButtonText` | String | Details \ud83d\udc40 | False | Configures the button text for notifications for App Updates notifications |
| `Mode` | Bool | False | False | Configures the app to use Intune for application information. Only supports PKG and DMG type apps, not LOB. |
| `LogFolders` | Array | /Library/Logs/Microsoft | False | Configures the log folders to gather logs from. Only used when gathering logs. |
| `Actions` | Array | None | False | Configures custom actions to add to the tray menu. See example below. |
| `ShowMenuToggle` | Bool | True | False | Configures whether to show the menu toggle button in the apps side menu. |
| `ShowDesktopInfo` | Bool | False | False | Configures whether to show information on the desktop. |
| `DesktopPosition` | String | TopRight | False | Configures the position of the desktop info, available positions are: `TopLeft`, `TopRight`, `BottomLeft`, `BottomRight` |
| `DesktopInfoLevel` | String | Full | False | Configures the level of information to show on the desktop, available levels are: `Minimal`, `Hardware`, `Full`, `Custom` |
| `DesktopInfoCustomItems` | Array | None | False | If `DesktopInfoLevel` is set to `Custom`, use this array to determine which information to show. Available info are: `HostName`, `Model`, `SerialNumber`, `Processor`, `IpAddress`, `MemSize`, `OsBuild`, `OsVersion`, `LastBootTime`, `StorageInfo`, `SupportPhone`, `SupportEmail`, `Separator` |
| `DesktopInfoBackgroundColor` | String | Transparent | False | Configures the background color for the desktop info. Configure using Hex format |
| `DesktopInfoBackgroundOpacity` | Real | 0.001 | False | Configures the background opacity for the desktop info. Configure a value between 1.0 - 0.1 |
| `DesktopInfoFontSize` | Integer | 14 | False | Configures the font size for the desktop info. |
| `CustomCardsPath` | String | None | False | Configures a path to a JSON file containing custom widgets to show on the Home view. |

### Example Configuration

To switch from Munki to Intune for application information, add the following key to the profile:
```xml
<key>IntuneMode</key>
<true/>
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>PayloadContent</key>
    <array>
      <dict>
        <key>BrandName</key>
        <string>AwesomeCorp</string>
        <key>ChangePasswordMode</key>
        <string>SSOExtension</string>
        <key>CustomColors</key>
        <array>
          <dict>
            <key>PrimaryColor</key>
            <string>#00A0D0</string>
            <key>AccentColor</key>
            <string>#45637A</string>
          </dict>
        </array>
        <key>Actions</key>
        <array>
           <dict>
               <key>Name</key>
               <string>Restart clipboard 🥹</string>
               <key>Command</key>
               <string>killall pboard</string>
           </dict>
           <dict>
               <key>Name</key>
               <string>Restart Intune Agent ⚡️</string>
               <key>Command</key>
               <string>/usr/bin/osascript -e 'do shell script \"sudo killall IntuneMdmAgent\" with administrator privileges'</string>
           </dict>
            <dict>
                <key>Name</key>
                <string>️Some awesome action</string>
                <key>Command</key>
                <string>echo "I am awesome"</string>
                <!-- Optional key to specify an icon for the action which will display in the self service view -->
                <key>Icon</key>
                <string>AppleFinder</string>
            </dict>
        </array>
        <key>NotificationTitle</key>
        <string>AwesomeCorp IT</string>
        <key>PayloadDisplayName</key>
        <string>SupportCompanion</string>
        <key>PayloadIdentifier</key>
        <string>SupportCompanion</string>
        <key>PayloadType</key>
        <string>SupportCompanion</string>
        <key>PayloadUUID</key>
        <string>a7a0d79f-1cf0-42f2-bc7e-e67d7413a3c5</string>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>SupportEmail</key>
        <string>demo@example.com</string>
        <key>SupportPhone</key>
        <string>123-456-789</string>
        <key>SupportUrl</key>
        <string>https://awesomecorp.support</string>
      </dict>
    </array>
    <key>PayloadDisplayName</key>
    <string>SupportCompanion</string>
    <key>PayloadIdentifier</key>
    <string>9c4a8e5e-4c70-4b82-83f7-44a053c146f4</string>
    <key>PayloadType</key>
    <string>Configuration</string>
    <key>PayloadUUID</key>
    <string>3D47F3E6-62ED-4668-A30F-6DA1DAE87B18</string>
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

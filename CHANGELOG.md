# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0.2] - 2024-12-06
### Changed
- Added a softer shade of orange and red when light mode is enabled to improve visibility and readability.

### Added
- Option to hide Categories and Dividers on the Desktop Info view. This allows for a cleaner and more focused view of the information displayed. Example configuration:
```xml
<key>DesktopInfoHideItems</key>
<array>
    <string>Category</string>
    <string>Divider</string>
</array>
```

## [2.0.1] - 2024-12-05
### Changed
- Added a preinstall script that will uninstall version 1.X if found.

## [2.0.0] - 2024-12-02
### AKA the Swift Update

### Changed
- The entire project has been migrated from **C# and AvaloniaUI/SukiUI** to **Swift and SwiftUI**, bringing significant improvements:
  - A more responsive and fluid user interface.
  - A native macOS look and feel for a seamless experience.
  - Superior memory management and overall performance enhancements.

- The following configurations and identifiers have changed:
  - **Bundle ID**: Updated, requiring the uninstallation of version 1.x before installing 2.0.
  - **Icons**: Redesigned for better alignment with macOS standards.
  - **Configuration Keys**: Some keys have been deprecated or updated.

### Deprecated
The following configuration keys have been removed:
- `BrandColor`
- `HiddenWidgets`
- `CustomColors`
- `IntuneMode`
- `ShowMenuToggle`
- `DesktopInfoCustomItems`
- `DesktopInfoBackgroundColor`
- `DesktopInfoColorHighlight`
- `CustomWidgetsPath`
- `SystemProfilerApps`

### Updated
- **`DesktopInfoLevel`**:
  - Previously a `string`, now an `integer`.
  - Removed string values: `Minimal`, `Hardware`, `Full`, `Custom`.
  - Added numeric levels: `1-5`.

### Notes
- A clean uninstall of version 1.x is required before installing 2.0. Use the script located at:
  ```bash
  /Applications/Utilities/SupportCompanion.app/Contents/Resources/Uninstall.sh
  ```
  For additional migration information, refer to the [migration guide](https://github.com/macadmins/SupportCompanion/wiki/Migrating-from-version-1.X-to-2.0).

## [1.4.0] - 2024-11-06
### Changed
- Avalonia and SukiUI has been updated.
- As part of the SukiUI update, the SukiHost has been updated to use the new scalable style of hosts.
- Mainwindow height has been slightly increased.
- Uninstall script updated with a check for root and use of Apple best practices. #50 thanks @pboushy

### Fixed
- When a app or system update notification was clicked, the command was not run resulting in nothing happening.
- ToolTips were not being shown.

## [1.3.0] - 2024-09-19
### Added
- A new mode for the app called `SystemProfilerApps` which allows for the app to display applications installed under `/Applications` and their version numbers as well as Architecture. This mode is useful for admins who want to see what applications are installed on the device and their version numbers. To enable this mode, set `SystemProfilerApps` to `true` in the configuration. Example configuration:
```xml
<key>SystemProfilerApps</key>
<true/>
```
- A new page called `Self Service` that will display all actions configured by an admin in the mobileconfig using the `Actions` array. This allows for easy access to self-service actions that the user can perform on their device. If no actions are configured, the page will not be displayed.
- A new key for configuring an icon for actions that will be displayed in the `Self Service` page. This allows for admins to configure an icon for each action that is displayed in the `Self Service` page. The icon should be a material icon name from https://pictogrammers.com/library/mdi/. For example `apple-finder` would be `AppleFinder`. Example configuration:
```xml
<key>Actions</key>
<array>
    <dict>
        <key>Name</key>
        <string>Restart clipboard</string>
        <key>Command</key>
        <string>killall pboard</string>
        <key>Icon</key>
        <string>AppleFinder</string>
    </dict>
```
### Changed
- If a widget is configured to not be shown or otherwise should not be shown, the widget will now be blanked out instead of being hidden. This is to ensure that the layout of the widgets is consistent and that the user knows that the widget is not available.

## [1.2.0] - 2024-09-04
### Added
- German localization, thanks @motodotsh for the German localization
- A new suite package that contains the main app and the LaunchAgent package. This allows for admins to install both the main app and the LaunchAgent using a single package
- A new option to use custom widgets on the Home view of the app. This allows for admins to add custom widgets to the Home view of the app to display information that is relevant to the user. This is done by using a JSON file populated any way the admin sees fit. To add custom widgets, add the below key to the mobileconfig and configure a JSON like the below example
  - The `icon` key should be a material icon name from https://pictogrammers.com/library/mdi/. For example `apple-finder` would be `AppleFinder`
```xml
<key>CustomWidgetsPath</key>
<string>/path/to/custom/widgets.json</string>
```
```json
[
  {
    "icon": "Laptop",
    "header": "Custom Widget",
    "data": {
      "Custom Label1": "A long example of a custom value with word wrap",
      "Custom Label2": "Custom Value2"
    }
  }
]
```

### Changed
- Updated the LaunchAgent to launch the process using `ProcessType` `Interactive` as the UI was sluggish when launched as a background process
- Tray Icon is now a outlined version of the logo to make it look more native on macOS. It's also a macOS template image which means it will change color based on the user's wallpaper
- Avalonia has been updated to 11.1.3

## [1.1.0] - 2024-06-24
### Added
- A package for a LaunchAgent which is signed and notarized using the same certificate as the main app
  - The LaunchAgent is configured to run the app at login, when activated and also start the app if closed by the user
- An option to disable all notifications, to disable notifications, set the value for `NotificationInterval` to `0`
- A new feature to show information about the device and support contact information on the desktop background. This allows for admins to show information about the device and support contact information on the desktop background. The information is displayed in any corner of the desktop background and can be customized using the configuration. Example configuration:
```xml
<key>ShowDesktopInfo</key>
<true/>
<key>DesktopInfoFontSize</key>
<integer>19</integer>
<key>DesktopInfoLevel</key>
<string>Custom</string>
<key>DesktopInfoCustomItems</key>
<array>
    <string>HostName</string>
    <string>SerialNumber</string>
    <string>SupportEmail</string>
</array>
<key>DesktopInfoBackgroundColor</key>
<string>#000000</string>
<key>DesktopInfoBackgroundOpacity</key>
<real>0.6</real>
<key>DesktopInfoColorHighlight</key>
<false/>
<key>DesktopPosition</key>
<string>BottomRight</string>
```
### Changed
- Line breaks and white space is removed when `BrandLogo` is parsed as a base64 string to ensure that the logo is displayed correctly in the side menu
- Post-install script now re-launches the app after the installation is complete to ensure that the app is running with the latest version
### Fixed
- AD Password Expiry color was not being set correctly in the UI. This has been fixed by setting the color based on the number of days until the password expires

## [1.0.7] - 2024-06-19
### Added
- A package for the LaunchAgent which is signed and notarized using the same certificate as the main app
- An option to disable all notifications, the disable notifications set the value for `NotificationInterval` to 0
- The option to show information about the device and support contact information on the desktop background. This allows for admins to show information about the device and support contact information on the desktop background. The information is displayed in any corner of the desktop background and can be customized using the configuration. Example configuration:
```xml
<key>ShowDesktopInfo</key>
<true/>
<key>FontSize</key>
<integer>19</integer>
<key>DesktopInfoLevel</key>
<string>Custom</string>
<key>DesktopInfoCustomItems</key>
<array>
    <string>HostName</string>
    <string>SerialNumber</string>
    <string>SupportEmail</string>
</array>
<key>DesktopInfoBackgroundColor</key>
<string>#000000</string>
<key>DesktopInfoBackgroundOpacity</key>
<real>0.6</real>
<key>DesktopInfoColorHighlight</key>
<false/>
<key>DesktopPosition</key>
<string>BottomRight</string>
```
### Changed
- Line breaks and white space is removed when `BrandLogo` is parsed as a base64 string to ensure that the logo is displayed correctly in the side menu
- Post-install script now re-launches the app after the installation is complete to ensure that the app is running with the latest version
### Fixed
- AD Password Expiry color was not being set correctly in the UI. This has been fixed by setting the color based on the number of days until the password expires

## [1.0.6] - 2024-06-17
### Fixed
- Not configuring the `BrandLogo` in the configuration would cause the app to crash on startup. This has been fixed by adding a check to see if the `BrandLogo` is configured before trying to load it

## [1.0.5] - 2024-06-10
### Added
- Added a new configuration to disable the menu toggle button in the app. This allows for admins to disable the menu toggle button if they want to prevent users from hiding the menu. Example configuration: https://github.com/macadmins/SupportCompanion/issues/38
```xml
<key>ShowMenuToggle</key>
<false/>
```
- Option to start the app using a URL scheme. This allows for admins to start the app using a URL scheme, which can be useful for starting the app from a script or another app. The URL scheme is `supportcompanion://home`. When started using the URL scheme, the app will exit when the window is closed instead of running in the background https://github.com/macadmins/SupportCompanion/issues/36
- Option to provide the `BrandLogo` as a base64 string in the configuration. This allows for admins to provide the `BrandLogo` as a base64 string in the configuration instead of a local path. This can be useful for providing the logo as part of a configuration profile. Example configuration:
```xml
<key>BrandLogo</key>
<string>{BASE64 STRING}</string>
```
- Norwegian localization, thanks @johnhans for the Norwegian localization
### Changed
- Margins around `BrandLogo` has been increased to make it look better in the side menu
### Fixed
- The `BrandName` was always displayed in white text in the side menu, which made it hard to read if light mode was enabled. Text color property has been removed to ensure it is set dynamically based on the user's system preferences https://github.com/macadmins/SupportCompanion/issues/39

## [1.0.4] - 2024-05-31
### Added
- Localized the app to `Swedish` and `French`. The app will now display in the user's preferred language if it is set to one of these languages in macOS. If the user's preferred language is not one of these, the app will default to English. Thank you, @hachirotahoshino, for the French localization https://github.com/macadmins/SupportCompanion/issues/31
- New configuration key to allow for adding a company logo to the side menu of the app. This allows for admins to add their company logo to the app to make it more personalized. Example configuration:
```xml
<key>BrandLogo</key>
<key>/local/path/to/logo.png</key>
```
### Changed
- Pending apps tooltip in Intune mode now adds the application name to the tooltip to make it easier to see which apps are pending if they have long names https://github.com/macadmins/SupportCompanion/issues/30
- Tray icon has been changed to a monochrome version https://github.com/macadmins/SupportCompanion/issues/34
- Emojis removed from tray menu to conform to Apple design guidelines 🥺 https://github.com/macadmins/SupportCompanion/issues/34
- Email address in the support info dialog now has a `mailto:` link to make it easier for users to contact support
  - As it is a link, the color of the email address has been changed to blue to indicate that it is clickable
### Fixed
- Identity view crashed the app if Kerberos SSO information failed to be retrieved. This has been fixed by using a `TryGetValue` on the dictionary to avoid a crash if the key is not present https://github.com/macadmins/SupportCompanion/issues/28
- Email address in the support info dialog did not display the entire email address if it was too long. This has been fixed by adding a word wrap https://github.com/macadmins/SupportCompanion/issues/29

## [1.0.3] - 2024-05-28
### Fixed
- Notification Interval failed to be cast as an integer, causing the app to crash on initialization. The value is now converted from NSNumber to Int before being used in the app.

## [1.0.2] - 2024-05-27
### Changed
- Changed the configuration of the custom tray menu actions to use `Name` and `Command` keys for better readability.

### Fixed
- The Munki update percentage was not being updated correctly in the UI as apps were updated.

## [1.0.1] - 2024-05-27
### Added
- Added a new configuration option to allow for adding custom actions to the tray menu. This allows for admins to add custom actions to the tray menu for common tasks that the user might perform for support purposes, such as restarting a service or running a script. Example configuration:
```xml
<key>Actions</key>
<array>
    <dict>
        <key>Restart clipboard 🥹</key>
        <string>killall pboard</string>
    </dict>
    <dict>
        <key>Restart Intune Agent ⚡️</key>
        <string>/usr/bin/osascript -e 'do shell script \"sudo killall IntuneMdmAgent\" with administrator privileges'</string>
    </dict>
</array>
```


## [1.0.0] - 2024-05-25
This is the first production release of Support Companion! :tada:

# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.5] -
### Added
- Added a new configuration to disable the menu toggle button in the app. This allows for admins to disable the menu toggle button if they want to prevent users from hiding the menu. Example configuration:
```xml
<key>ShowMenuToggle</key>
<false/>
```

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
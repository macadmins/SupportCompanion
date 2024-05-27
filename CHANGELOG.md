# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
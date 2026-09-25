# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-09-17
### Breaking changes
- **Privileged settings are only read when set by an administrator.** `IsPrivileged` on `Actions`, `RequirePrivilegedActionAuthentication`, and the elevation settings (`EnableElevation`, `MaxElevationTime`, `RequireResonForElevation`, `ReasonMinLength`, `ElevationWebhookUrl`, `ElevationSeverity`) are now only honored when they come from a configuration profile or `/Library/Preferences`. These settings decide what runs as root and who gets administrator rights, so honoring them from a domain the user can write to was a local privilege escalation. Actions defined in the user's own preferences still run, but never with privileges, and `RequirePrivilegedActionAuthentication` defaults to `true` unless an administrator sets it. **If you deploy these settings with `defaults write` as the user, move them to a configuration profile or `/Library/Preferences`.**
- **Fleet mode is selected automatically** on Macs with Fleet's agent (orbit) installed when no other mode matches. Before, these Macs used System Profiler mode. Set `Mode` explicitly to keep a different mode.
- **The privileged helper is installed by the package's `helper_install.zsh`**, which places it in `/Library/PrivilegedHelperTools` and loads its LaunchDaemon. `SMJobBless` is deprecated in macOS 14 and later; `SMAppService` registration remains only as a fallback for a Mac where the packaged helper is missing, and is skipped entirely when `SkipHelperInstall` says the helper is deployed declaratively.
- **Existing helper installs:** the package now replaces the helper on every install, unloading the old one first and loading the new one, and the install fails if the helper does not end up running. The app and the helper speak a versioned interface, so a Mac left with an older helper is not merely stale — every privileged operation fails — and that must not pass silently.
- **The helper only serves 3.0.0 and later clients.** A valid signature proves only that a connecting app is a Support Companion build signed by us, which every 2.x release satisfies too. Signature alone therefore cannot tell this version's client apart from an older one that enforced less, so the restrictions added here would not hold if an earlier build could still connect. The helper now checks the connecting app's version, requires it to be signed with the hardened runtime, and requires it to run from `/Applications/SupportCompanion.app`, which a standard user cannot write to.
- **The helper no longer runs commands on request.** Its interface was a pair of methods that ran any command or script as root, so every restriction on what could run — `IsPrivileged`, `EnableElevation` — was enforced only in the app, and any code running in the app process was equivalent to root. It now exposes named operations instead, and decides what each one runs. For privileged actions the app sends only the action's name; the helper looks the `Command` up in the administrator-managed preferences itself, so what runs as root always comes from an administrator. `EnableElevation` is re-checked in the helper rather than only hiding a button.

### Security
- **Temporary administrator rights are enforced by the helper, not the app.** The demotion timer used to run in the app and keep its deadline in `PrivilegeDemotionEndTime` in the user's own preferences, so quitting the app or deleting the key left the user an administrator indefinitely. Both the deadline and the timer live in the helper now, in a root-owned file under `/var/db/com.github.macadmins.SupportCompanion`, and demotion happens whether or not the app is running — including catching up on a deadline that passed while the Mac was off. The app's timer only drives the countdown.
- **Administrator rights granted to other accounts during an elevation are revoked.** Demoting the elevated account does nothing about a second administrator created while the window is open, which would outlive the elevation entirely. The helper watches the `admin` group for the length of the window, by short name and by UUID, and takes back rights granted to anyone who was not already an administrator when the window opened, repeatedly if they are granted again. The elevated user keeps their own rights until the timer runs out. Every grant and revocation is written to the root-owned log.
- **Elevation reasons are also recorded where the user cannot edit them.** The reason log in the user's Application Support folder is writable by that user, so it was never an audit trail. The helper keeps its own root-owned log alongside the elevation state. Reasons are flattened to a single line and bounded in length before being written, so a reason containing newlines cannot forge entries in that log, and one containing a great deal of text cannot inflate it.
- **Uninstalling hands back any administrator rights it was holding.** The uninstaller removes the helper, which is what would have taken those rights away, so uninstalling during an elevation window previously left the elevated user a permanent administrator. It now demotes anyone still elevated before removing anything, and clears the helper's state directory.
- **More than one user can be elevated at a time.** With fast user switching two accounts can each be logged in and each ask for rights. Each window is now tracked separately with its own deadline and timer, rather than the second replacing the first and leaving that user elevated with nothing left to demote them.
- The package's preinstall script now verifies that the 1.x `Uninstall.sh` it runs is owned by root and not writable by group or others before executing it.

### Added
- **`EnforceAdminAllowlist` and `PermanentAdmins`, to stop an elevation outliving its window.** The helper's deadline lives in a root-owned file, and a user who is briefly an administrator is briefly root, so they can delete it and restart the helper — leaving nothing to say a demotion was owed, and no way to tell their rights from a permanent administrator's. With an allowlist set, the helper reconciles the `admin` group at startup and every five minutes: anyone holding administrator rights who is neither in `PermanentAdmins` nor inside a live elevation window is demoted. Deleting the state file then removes the only evidence that an elevation was legitimate, so it ends the elevation rather than extending it. `root` is always permitted and never demoted, and the policy is re-read on every pass, so removing the profile only suspends enforcement while it is actually missing.

  **`EnforceAdminAllowlist` defaults to off, and `PermanentAdmins` must list every account that should keep administrator rights before it is turned on** — management accounts, break-glass accounts and permanently-admin staff included. This includes accounts granted administrator rights by something else, such as Platform SSO's `AdministratorGroups`: anything not on the list is demoted, and an identity provider that grants it again simply produces a demotion every five minutes. With it on and the list incomplete, those accounts are demoted within five minutes. An explicitly empty list is honored, meaning no account is permanently an administrator; a missing list is refused with an error rather than acted on. Both keys must come from a **device-scoped** profile or `/Library/Preferences`, since reconciliation runs when there is no logged-in user to attribute it to.

  Administrator group members that cannot be resolved to an account are reported and left alone rather than removed, since a failed lookup is not evidence that an entry does not belong. Entries that appear while an elevation is open are still revoked, because there the group's earlier state establishes that they are new.

  This is containment rather than prevention. Brief root access has other routes to persistence — a launch daemon, a sudoers drop-in, enabling the root account — which group membership does not show. Treat elevation as a speed bump with an audit trail, not as a boundary.
- **The helper can be deployed declaratively.** With `com.apple.configuration.services.background-tasks` (macOS 15+, supervised), the helper and its launchd job are placed in `/var/db/ManagedConfigurationFiles`, which the system will not let even root write to, and the job cannot be unloaded or disabled — so an elevated user cannot stop the process that will demote them. `DDM/make_ddm_assets.zsh` builds the archive, the launchd job and the declarations from a built app. This is the recommended deployment wherever `EnableElevation` is used.
- `SkipHelperInstall`, which stops the package installing and loading its own copy of the helper, for Macs where it is deployed declaratively. Set it in a **device-scoped** profile: a user-scoped one is not readable by an installer script. Only honored from a configuration profile or `/Library/Preferences`.
- `ElevationAllowedAdmins`, a list of account names the elevation watchdog ignores, for management accounts an MDM may legitimately add while somebody is elevated. Read from a **device-scoped** profile or `/Library/Preferences`, like the other elevation enforcement keys.
- **Fleet mode.** Support Companion now integrates with [Fleet](https://fleetdm.com), using the Fleet device API with the device's own token, so no API keys are needed. Fleet mode is used when Fleet's agent (orbit) is installed, when the MDM server is the Fleet server, or when `Mode` is set to `Fleet`. The Fleet server URL is read from fleetd's configuration profile or orbit's LaunchDaemon. It can be overridden with `FleetUrl`, which is only honored when set by a configuration profile or in `/Library/Preferences`, since the device token is sent to that server. Example configuration:
```xml
<key>Mode</key>
<string>Fleet</string>
```
- **Self-service apps.** In Fleet mode the Apps page shows the device's Fleet self-service software, with search, category filters and collapsible Updates Available, Available and Installed sections. Apps can be installed, updated, reinstalled and uninstalled. Progress is followed until Fleet reports the result, and the output of failed installs can be viewed from the app card. Updates stay listed until the new version is actually installed.
- Custom button text per app, for example "Request" for an app named "Request software". Keys are the software title ID, display name or name; values are either a string that replaces the Install label, or a dictionary with `Install`, `Update`, `Reinstall` and `Uninstall`. Example configuration:
```xml
<key>FleetButtonLabels</key>
<dict>
    <key>Request software</key>
    <string>Request</string>
    <key>42</key>
    <dict>
        <key>Install</key>
        <string>Get</string>
        <key>Uninstall</key>
        <string>Remove</string>
    </dict>
</dict>
```
- A highlighted Recommended section at the top of the Apps page, listing apps IT recommends in the configured order. Entries are title IDs or names, and the section title can be changed. Example configuration:
```xml
<key>FleetRecommendedApps</key>
<array>
    <string>Slack</string>
    <string>42</string>
</array>
<key>FleetRecommendedTitle</key>
<string>Start here</string>
```
- App icons come from Fleet (custom and App Store icons), from the installed app, or from the icon set Fleet's own web pages use. That icon set is loaded from Fleet's GitHub repository and cached, and apps without an icon get a letter tile. To stop requests to GitHub:
```xml
<key>FleetIconsFromGitHub</key>
<false/>
```
- **Updates blocked by an open app.** When an install doesn't run because the app is open, the app card shows "Waiting for app to close" instead of "Install failed", with a **Quit & Update** button that quits the app gracefully (it can still prompt to save) and installs again. This works for Fleet-maintained apps with patch when closed, and for custom packages whose install script prints a message about the app being open. The built-in phrases can be replaced with your scripts' exact messages; an empty array turns detection off for custom packages. Example configuration:
```xml
<key>FleetAppOpenMessages</key>
<array>
    <string>Please close Chrome before updating</string>
</array>
```
- **Home cards.** In Fleet mode the patching progress and pending updates cards use Fleet's self-service updates, and the Apps sidebar item shows the number of updates.
- A **Device Compliance** card listing failing Fleet policies with their resolution text, critical ones first, and a collapsible list of passing checks. Its **Re-check** button asks Fleet to refresh the device's details and re-run its policies. While any check fails, a banner at the top of Home shows what needs attention. The card can be hidden using `HiddenCards`, which also hides the banner, badges and policy notifications:
```xml
<key>HiddenCards</key>
<array>
    <string>FleetPolicies</string>
</array>
```
- A **Fleet** card showing the device's Fleet host ID, team, last check-in, last inventory update and server. It can be hidden using `HiddenCards`:
```xml
<key>HiddenCards</key>
<array>
    <string>Fleet</string>
</array>
```
- The tray menu shows compact Device Compliance and Fleet cards in Fleet mode. The compliance card has Re-check and Details buttons.
- **Fleet notifications**, each on by default:
    - When an install, update, reinstall or uninstall started from Support Companion finishes or fails, or needs the app to be closed (with a Quit & Update button). Turn off with `FleetNotifyInstallResults`.
    - When updates are available, listing the apps, with an **Update Now** button that installs them. Clicking the notification opens the Apps page. Uses `AppUpdateNotificationMessage`, `AppUpdateNotificationButtonText` and `NotificationInterval`. Turn off with `FleetNotifyUpdates`.
    - When a policy starts failing, sent once per failure. Turn off with `FleetNotifyPolicies`.
```xml
<key>FleetNotifyInstallResults</key>
<false/>
<key>FleetNotifyUpdates</key>
<false/>
<key>FleetNotifyPolicies</key>
<false/>
```
- Failing compliance checks count toward the tray menu icon's badge and the Dock badge, and are shown as a badge on the Home sidebar item.
- Support for Background Security Improvements. If the pending update is a background security improvement, clicking the update will open the relevant pane in system settings.
- WiFi SSID information is now included in the device information
- New option to hide tray menu icon. This allows for using the desktop information window without displaying the tray menu icon. Example configuration:
```xml
<key>TrayMenuShowIcon</key>
<false/>
```
- Support for monitoring Jamf application patches. When in Jamf mode, the app will now monitor for pending application patches and display them in the tray menu as well as in the main app. The badge will also be displayed in the tray menu icon when there are pending application patches. Requires the use of Self Service+.
    - Correctly monitoring application patches from Self Service+ requires that Self Service+ is configured for SSO and that `Enable Self Service user login` is **not** checked in the Self Service configuration in Jamf Pro. This is because the data in the app is lazy updated when the user starts and authenticates in Self Service+. To work around this, Support Companion will briefly launch Self Service+ in the background to update the patch data. An icon will appear in the dock while this is happening. This process should only take a few seconds.
    - Can be turned off by setting `RefreshSelfService` to `false` in the configuration. Example configuration:
```xml
<key>RefreshSelfService</key>
<false/>
```
- A new default card for Jamf mode that displays the last time the device checked in, the last inventory time and the MDM enrollment time as well as the ID of the device in Jamf. This card is only displayed when in Jamf mode and can be hidden using the `HiddenCards` configuration.
```xml
<key>HiddenCards</key>
<array>
    <string>Jamf</string>
</array>
```
- A new option for Jamf mode to set the polling interval for logs collection to gather last check in time and last inventory time. This allows for admins to set how often the app should check for new log data. By default, the interval is set to 36 hours. Example configuration:
```xml
<key>JamfLogPollHours</key>
<integer>46</integer>
```
- Logging will now be done in a log file located at `~/Library/Logs/SupportCompanion/SupportCompanion.log` in addition to os log. This allows for easier troubleshooting of issues with the app. The log file will be rotated when it reaches 5 MB in size. Debug logging can be enabled by setting `DebugLogging` to `true` in the configuration. Example configuration:
```xml
<key>DebugLogging</key>
<true/>
```

### Changed
- Pending updates count is now shown as a badge on the sidebar navigation item, making it visible without opening the updates view.
- Accessibility labels added to icon-only buttons for improved VoiceOver support.
- Significant internal code quality improvements: preferences split into focused sub-objects, helpers refactored into dedicated files, Timer-based polling migrated to Swift structured concurrency, and improved error handling with logging throughout.
- If `BrandName` is configured, it will now be displayed in the desktop information window as well as the header instead of "Device Information".
- A new localized message will be displayed in the applications view stating that the apps are installed by the `mode`. This is to clarify the view only displays apps installed by the MDM and not all apps installed on the device.
- User info will now use OpenDirectory to gather user information instead of `finger` command.
- A delay has been added to `InfoHelp` when hovering over the info icon to prevent accidental triggering of the help popup.
- App update names line limit has been increased to `2` lines to prevent truncation of long app names.
- Add support for a custom Company Portal URL (e.g. GCC High / sovereign cloud endpoints) and harden the Intune MDM detection logic so it correctly identifies Intune across all manage.microsoft.* domains while avoiding obvious false positives. Thanks @Actu4l-Human.
- Clicking a notification about apps now opens the relevant page in Support Companion, handled by the running app.
- The Dock badge updates as soon as the number of pending items changes, and no longer counts items whose card or button is hidden.
- Much lower resource use on the Home page: the patch progress wave is drawn with Core Animation. With Home open, memory use went from about 140 MB to about 55 MB, and CPU use from 30–40% to about 0%. Reduce Motion still stops the animation.
- Views only update when the data they show changes, and preference changes from a configuration profile or `defaults write` show up right away.
- The battery card's Time to Full shows Fully Charged, Not Charging or Calculating… instead of N/A while on external power. The temperature row is hidden when no reading is available, and copied device info uses the system's temperature unit.
- The tray menu popover closes when clicking outside it, pressing Escape, or opening the main window.

### Fixed
- **Opening a web page in the sidebar — Knowledge Base or Company Portal — could crash the app.** The embedded web view was sized from its own content, and the page reflowed to whatever size it was given, so each layout pass changed the size that drove the next one. SwiftUI reported the resulting dependency cycles and eventually crashed laying out the view. The web view now takes the size it is offered. Its navigation delegate was also being replaced by one that updated loading state synchronously, which could invalidate the view while it was being evaluated; the web view's own delegate, which defers those updates, is left in place.
- The CLI built its `supportcompanion://run` URL by interpolation, so action names containing `&`, `#` or spaces were misrouted. It now uses `URLComponents`.
- Removed an undefined variable from the package's postinstall script, and balanced a quote in the helper's linker flags that absorbed the following flag.
- File watcher would not correctly detect changes on custom JSON cards if the file was replaced instead of modified. This has been fixed by using a different method to monitor file changes.
- The pending updates badge on `Software Updates` was transparent in the main app.
- `FileVault` did not hide the item on the desktop information window when configured to be hidden.
- The MDM enrollment date is now found by the MDM payload instead of the profile name, so it works for MDMs other than Jamf and Intune instead of failing.
- Mode detection now compares the MDM server's host correctly. The MDM URL is read without its scheme, so the host comparison never ran before.
- A notification without a button could remove the button from earlier notifications still in Notification Center.
- On macOS 27 the tray menu popover closed a few seconds after opening, for example in Jamf mode while Self Service+ was refreshed in the background.
- On macOS 27 the battery card showed 0% health and 0.0 °C.
- Commands that print a lot of output, such as gathering logs over a long period, could hang.
- Commands and actions containing single quotes didn't run correctly.
- Jamf patches ran as the user with UID 504 instead of the logged-in user.
- Mode detection stopped before choosing a mode when the MDM server was Intune or Jamf, so the mode was never set on those Macs.
- On non-English systems, hiding the Battery or Evergreen card with `HiddenCards` didn't stop their background refresh.
- The "Updating…" label for Jamf patches didn't update.
- Web views could be created twice for the same tab, and monitoring (for example battery) kept running after the main window was closed.
- Swedish and French restart countdown translations.

### Notes for Fleet mode
- Requires Fleet's agent (orbit) on the device. Features follow what the Fleet server supports; the Fleet flag for skipped patch-when-closed installs (`skipped_install`) is newer than Fleet 4.91, and older servers are handled through the install output instead.
- Fleet Desktop single sign-on isn't supported yet. It hasn't shipped in a Fleet release.

## [2.3.1] - 2025-10-06
### Changed
- Refactored the uninstall script with better error handling and logging.

## [2.3.0] - 2025-09-18
### Changed
- Updated UI elements to match the new look introduced in macOS 26 (Tahoe).
- Cards now use the liquid glass effect and updated corner radius to better align with the new design language.
- Moved the dark/light mode toggle and support info button to the top-right toolbar.
- Added reboot reminder notifications, turned off by default and can be enabled using the key `RebootReminderDays`. Example configuration,
```xml
<key>RebootReminderDays</key>
<integer>7</integer>
```
- Minor UI tweaks for cards, removed shadows for text.
- Removed entitlements from helper to reduce attack surface.

## [2.2.2] - 2025-06-13
### Fixed
- Last restart now correctly displays the time since last restart in the correct format when copying device information to the clipboard.

### Added
- A new option to exclude certain folders from log collection. This allows for admins to exclude certain folders from being collected when the user runs the log collection action. This can be useful for excluding large folders that are not relevant to the support case or for excluding folders that contain sensitive information. Example configuration:
```xml
<key>ExcludedLogFolders</key>
<array>
    <string>/Library/Logs/Microsoft/mdatp</string>
</array>
```

## [2.2.1] - 2025-02-26
### Fixed
- Even if `SoftwareUpdates` or `PendingAppUpdates` were hidden, the badge would still be displayed in the tray menu and dock. This has been fixed by checking if the widget is hidden before displaying the badge.

### Added
- A new option to set a custom branding tray menu icon by specifying a base64 string of the icon using `TrayMenuBrandingIcon`. Note that the icon should be a monochrome icon to fit the design of the tray menu.


### Changed
- Additional options to the rendering of brand logos has been added that allows for a higher quality rendering of the logo as it in some cases could look blurry or jagged.

## [2.2.0] - 2025-01-07
### Changed
- A slight background has been added increasing visaibility of the text.
- Main window is now slightly resizeable to allow for window to be resized to a smaller size.
- Last reboot time is now monitored and updated every 5 minutes. Displaying in minutes, hours or days depending on the time since last reboot.
- Battery temperature will adapt to the configured measurement system in macOS and show temp in either Celsius or Fahrenheit.
- Storage API has been changed for a more accurate reading of actual storage used.
- "Is Admin" will now display "yes" or "no" localized instead of enabled or disabled.
- In addition to only checking if Company Portal exists when dynamically setting the `Mode` to use, the server url will now also be checked. If the server url contains "i.manage.microsoft.com", the MDM will be set to Intune. This is because Company Portal can validly exist on a device without the device being managed by Intune.
- Button labels on actions can now be set to a custom value. This allows for admins to set custom labels for actions that are displayed in the `Self Service` page. Example configuration:
```xml
<dict>
    <key>Command</key>
    <string>open https://github.com/macadmins/supportcompanion</string>
    <key>Description</key>
    <string/>
    <key>Icon</key>
    <string>heart.fill</string>
    <key>Name</key>
    <string>Open Intranet</string>
    <key>ButtonLabel</key>
    <string>Open</string>
</dict>
```

### Fixed
- Artifacts were being left behind on the desktop window when IP address was updated.

### Added
- The configured logo will now be displayed in the tray menu as well. Can be hidden by setting `ShowLogoInTrayMenu` to `false` in the configuration.
- A new option to show the desktop information window "frosted". This allows for a frosted glass effect on the desktop information window. Example configuration:
```xml
<key>DesktopInfoBackgroundFrosted</key>
<true/>
```
- A new option to show a custom view in the navigation bar based on a Markdown file. This allows for creating a custom view with custom information relevant to your organization. Example configuration:
```xml
<key>MarkdownFilePath</key>
<string>/path/to/custom/view.md</string>
<key>MarkdownMenuLabel</key>
<string>Custom View</string>
<key>MarkdownMenuIcon</key>
<string>doc.text</string>
```
- A new option to show custom cards in the navigation bar. This allows for displaying large numbers of cards without cluttering the home view, by moving them to their own view. Example configuration:
```xml
<key>CustomCardsMenuLabel</key>
<string>Custom Cards</string>
<key>CustomCardsMenuIcon</key>
<string>doc.text</string>
<key>CustomCardPath</key>
<string>/path/to/custom/cards.json</string>
```
- A new option to trigger actions using the CLI. This allows for triggering actions using the CLI instead of the UI. This can be useful for automating actions or triggering actions from a script. By default, actions configured as privileged will require authentication. This can be disabled by setting `RequirePrivilegedActionAuthentication` to `false`. Example usage:
```bash
/Applications/SupportCompanion.app/Contents/Resources/SupportCompanionCLI action "Restart clipboard"
```
- Additional arguments to the CLI to allow for getting additional information that is displayed in the app. Example usage:
```bash
/Applications/SupportCompanion.app/Contents/Resources/SupportCompanionCLI battery
```
Example output:
```plaintext
🔋 Battery Information
-----------------------
Health:          93% 🔋
Cycle Count:     37
Temperature:     36.7°C 🌡️
Charging Status: Not Charging
Time Remaining:  N/A
```
- A new feature that allows for user elevation of standard users to admin users. This feature is useful for instances where a user needs to perform an action that requires admin rights. The user can request elevation by clicking the `Elevate` button in the tray menu or Identity menu. The admin can configure wether a reason is required, how long the reason must be and if the reason should be sent via a webhook to a specified URL or saved to disk. Example configuration:
```xml
<key>EnableElevation</key>
<true/>
<key>RequireResonForElevation</key>
<true/>
<key>ReasonMinLength</key>
<integer>20</integer>
<key>MaxElevationTime</key>
<integer>60</integer>
<key>ElevationWebhookUrl</key>
<string>https://webhook.url</string>
<key>ShowElevateTrayCard</key>
<true/>
<key>ElevationSeverity</key>
<integer>6</integer>
```

Example of JSON payload sent to webhook:
```json
{
  "severity" : 6,
  "date" : "2024-12-16T11:21:01Z",
  "host" : "Tobias's MacBook",
  "user" : "tobias",
  "serial" : "H123456789",
  "reason" : "Awesome dev stuff"
}
```

## [2.1.0] - 2024-12-11
### Changed
- The tray menu has been changed to a custom menu that is an extension of the apps main UI. This allows for a more consistent look and feel between the tray menu and the main app. The tray menu now displays the same information as the main app, including device information, storage information and patching progress as well as actions. If you have custom actions configured using `Actions`, the first 6 actions will be displayed in the tray menu. If you have more than 6 actions, the rest can be run from the Self Service section in the main app.
- If the app is launched using the URL scheme `supportcompanion://`, the tray menu will not be displayed.
- Shadow for green text has been removed as it could make the text look blurry. Instead the green has been changed to a darker shade to make it more readable.
- Copy device info button will now include additional information about the device, including battery and storage. Example output:
```plaintext
--------------------- Device --------------------- 
Host Name: AwesomeMac
Serial Number: C0123456789
Model: MacBook Pro (14-inch, Nov 2023)
Processor: Apple M3 Pro
Memory: 36 GB
OS Version: 15.2.0
OS Build: 24C98
IP Address: 192.168.68.108
Last Reboot: 4 days
--------------------- Battery --------------------- 
Health: 94%
Cycle Count: 35
Temperature: 34.5°C
--------------------- Storage --------------------- 
Used: 74.9%
FileVault: Enabled
```

### Added
- Support for Japansese localization, thanks @kenchan0130 for the Japanese localization
- A badge to the tray menu icon that visually indicates that the user has pending updates to install.

## [2.0.2] - 2024-12-06
### Changed
- Added a softer shade of orange and red when light mode is enabled to improve visibility and readability.
- If launching the app using a URL scheme, the app will now exit **only** when `supportcompanion://` is used. This allows for the app to be started using a URL scheme and remain open when using `supportcompanion://home` or similar. Example:

Will exit when the window is closed:
```bash
open supportcompanion://
```

Will remain open when the window is closed:
```bash
open supportcompanion://home
```

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

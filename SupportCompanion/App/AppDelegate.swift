//
//  AppDelegate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import AppKit
import Combine
import Foundation
import SwiftUI
import UserNotifications

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    var popover: NSPopover!
    var statusItem: NSStatusItem?
    var windowController: NSWindowController?
    var transparentWindowController: TransparentWindowController?
    let appStateManager = AppStateManager.shared
    let elevationManager = ElevationManager.shared
    var mainWindow: NSWindow?
    static var urlLaunch = false
    static var shouldExit = false
    private var notificationDelegate: NotificationDelegate?
    private var trayIconObservation: ObservationToken?
    private var elevationCountdownObservation: ObservationToken?
    private var dockBadgeObservation: ObservationToken?
    private var popoverEventMonitors: [Any] = []
    private var popoverKeyWindowObserver: NSObjectProtocol?
    private var trayManager: TrayMenuManager { TrayMenuManager.shared }

    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var hasUpdatesAvailable: Bool {
        appStateManager.attentionCount > 0
    }

    private func executeAction(_ action: Action) {
        Task {
            do {
                _ = try await ExecutionService.runAction(action)
            } catch {
                Logger.shared.logError("Failed to execute action: \(error)")
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // Installers the user double-clicked, when this app is registered to open them. Taken before
        // the custom scheme is looked at: these are file URLs and have no host to switch on.
        let installers = urls.filter {
            $0.isFileURL && InstallerFileTypes.fileExtensions.contains($0.pathExtension.lowercased())
        }

        if let first = installers.first {
            AppDelegate.shouldExit = false

            // One at a time. The rest go where they would have gone anyway rather than queueing up
            // behind a window the user has not answered yet.
            for other in installers.dropFirst() {
                NSWorkspace.shared.open(other)
            }

            UserInstallManager.shared.open(first)
            return
        }

        guard let url = urls.first else { return }

        if url.host == "run" {
            Logger.shared.logDebug("Received run command request")
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            {
                if let actionName = queryItems.first(where: { $0.name == "action" })?.value {
                    // Get the action details
                    if let action = appStateManager.preferences.actions.first(where: {
                        $0.name == actionName
                    }) {
                        Logger.shared.logDebug("Found action: \(action.name)")
                        if action.isPrivileged ?? false
                            && appStateManager.preferences.requirePrivilegedActionAuthentication
                        {
                            Logger.shared.logDebug("Action requires authentication")
                            authenticateWithTouchIDOrPassword(
                                completion: { success in
                                    if success {
                                        self.executeAction(action)
                                    } else {
                                        Logger.shared.logError(
                                            "Authentication failed. Action: \(action.name) was not executed."
                                        )
                                    }
                                }, reason: "authenticate to execute this privileged action.")
                        } else {
                            Logger.shared.logDebug("Executing action: \(action.name)")
                            self.executeAction(action)
                        }
                    } else {
                        Logger.shared.logError("Action not found: \(actionName)")
                    }
                }
            }
            return
        }

        switch url.host?.lowercased() {
        case nil:
            AppDelegate.shouldExit = true
            if let statusItem = statusItem {
                Logger.shared.logDebug("Removing status item")
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        default:
            AppDelegate.shouldExit = false
        }
        AppDelegate.urlLaunch = true
        showWindow()
        NotificationCenter.default.post(name: .handleIncomingURL, object: url)
    }

    /// The Services menu item, for an installer the user right-clicked in Finder.
    @objc func installOpenedInstaller(
        _ pasteboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard
            let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
            let first = urls.first(where: {
                InstallerFileTypes.fileExtensions.contains($0.pathExtension.lowercased())
            })
        else {
            error.pointee = "No installer package or disk image was selected" as NSString
            return
        }

        UserInstallManager.shared.open(first)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted in the app; don't start the menu bar item, timers, or notifications for them
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else {
            return
        }

        if !AppDelegate.shouldExit && appStateManager.preferences.trayMenuShowIcon {
            setupTrayMenu()
        }

        popover = NSPopover()
        // Not .transient: that closes the popover whenever the app resigns active, which
        // happens when the Jamf install percentage refresh force-quits Self Service+ (macOS 27).
        // Outside clicks and Escape are handled by installPopoverEventMonitors() instead.
        popover.behavior = .applicationDefined
        popover.contentSize = NSSize(width: 500, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: TrayMenuView(
                viewModel: CardGridViewModel(appState: AppStateManager.shared)
            )
            .environment(AppStateManager.shared)
        )
        popover.delegate = self

        configureAppUpdateNotificationCommand()

        appStateManager.showWindowCallback = { [weak self] in
            self?.showWindow()
        }

        if appStateManager.preferences.desktopInfo.showDesktopInfo {
            // Initialize transparent window
            transparentWindowController = TransparentWindowController(appState: appStateManager)
            transparentWindowController?.showWindow(nil)

            // Make sure the transparent window is set up correctly
            if let window = NSApplication.shared.windows.first {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }

        // The right-click "Install with Support Companion" item.
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()

        // Whether Finder actually offers it. Applied on every launch rather than once, so turning the
        // preference off takes the item away again.
        InstallerServiceMenu.apply(showing: appStateManager.preferences.showInstallerServiceMenuItem)

        // What this process read, so that a disagreement with the helper — which reads the same
        // setting by a different route — is visible in one place.
        Logger.shared.logInfo(
            "User installs: EnableUserInstalls=\(appStateManager.preferences.enableUserInstalls)"
        )

        requestNotificationPermissions()
        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        appStateManager.startBackgroundTasks()
        appStateManager.refreshAll()
        checkAndHandleDemotionOnLaunch()
        if !appStateManager.preferences.hiddenCards.contains(Constants.Cards.jamfInfo)
            && appStateManager.preferences.mode == Constants.Modes.jamf
        {
            Task {
                let id: String
                do {
                    id = try await getJamfId()
                } catch {
                    Logger.shared.logError("getJamfId failed: \(error.localizedDescription)")
                    id = "Unknown"
                }
                await MainActor.run {
                    AppStateManager.shared.jamfId = id
                    AppStateManager.shared.jamfInfoManager.refresh()
                }
            }
        }
    }

    private func checkAndHandleDemotionOnLaunch() {
        // Demotion is the helper's job and it happens whether or not this app is running, including
        // while it was quit. All there is to do at launch is pick up the countdown already in progress.
        Task { @MainActor in
            let remainingTime = await elevationManager.remainingElevationTime()

            guard remainingTime > 0 else { return }

            elevationManager.startDemotionTimer(duration: remainingTime) { remainingTime in
                Task { @MainActor in
                    AppStateManager.shared.timeToDemote = remainingTime
                    AppStateManager.shared.isDemotionActive = remainingTime > 0
                }
            }
        }
    }

    private func setupTrayMenu() {
        let trayManager = TrayMenuManager.shared
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            setupTrayMenuIconBinding()

            if let button = trayManager.getStatusItem().button {
                button.action = #selector(togglePopover)
                button.target = self
            }
        }
    }

    func setupTrayMenuIconBinding() {
        // Updates or failing compliance checks
        let hasUpdates = { [unowned self] () -> Bool in
            self.appStateManager.attentionCount > 0
        }
        TrayMenuManager.shared.updateTrayIcon(hasUpdates: hasUpdates())
        dockBadgeObservation = observeChanges(of: { [unowned self] in
            self.appStateManager.attentionCount
        }) { count in
            BadgeManager.shared.incrementBadgeCount(count: count)
        }
        trayIconObservation = observeChanges(of: hasUpdates) { hasUpdates in
            TrayMenuManager.shared.updateTrayIcon(hasUpdates: hasUpdates)
        }

        // Count down next to the icon while administrator rights are held, so the time left is
        // visible without opening anything. The demotion timer already publishes once a second.
        let remaining = { [unowned self] () -> TimeInterval in
            self.appStateManager.isDemotionActive ? self.appStateManager.timeToDemote : 0
        }
        TrayMenuManager.shared.updateElevationCountdown(remaining: remaining())
        elevationCountdownObservation = observeChanges(of: remaining) { remaining in
            TrayMenuManager.shared.updateElevationCountdown(remaining: remaining)
        }
    }

    @MainActor
    class TrayMenuManager {
        static let shared = TrayMenuManager()
        let appStateManager = AppStateManager.shared
        let fileManager = FileManager.default
        private var statusItem: NSStatusItem

        private init() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            updateTrayIcon(hasUpdates: false)  // Default state
        }

        func updateTrayIcon(hasUpdates: Bool) {
            let iconName = "MenuIcon"
            let base64Logo = appStateManager.preferences.trayMenuBrandingIcon
            var showLogo = false
            var baseIcon: NSImage?

            showLogo = loadLogo(base64Logo: base64Logo)
            if showLogo {
                guard let data = Data(base64Encoded: base64Logo) else {
                    Logger.shared.logError("Error: Failed to decode base64 logo for tray icon")
                    return
                }
                baseIcon = NSImage(data: data)
            } else {
                baseIcon = NSImage(named: iconName)
            }

            guard let baseIcon = baseIcon else {
                Logger.shared.logError("Error: Failed to load tray menu icon")
                return
            }

            baseIcon.size = NSSize(width: 18, height: 18)
            baseIcon.isTemplate = true  // Ensure base icon respects system appearance

            if let button = statusItem.button {
                // Clear any existing layers
                button.layer?.sublayers?.forEach { $0.removeFromSuperlayer() }

                // Set the base icon as the button's image
                button.image = baseIcon
                button.image?.isTemplate = true

                if hasUpdates {
                    Logger.shared.logDebug("Updates available, adding badge to tray icon")

                    // Add badge dynamically as a layer
                    let badgeLayer = CALayer()
                    badgeLayer.backgroundColor = NSColor.red.cgColor
                    badgeLayer.frame = CGRect(
                        x: button.bounds.width - 15,  // Align to the lower-right corner
                        y: 13,  // Small offset from the bottom
                        width: 8,
                        height: 8
                    )
                    badgeLayer.cornerRadius = 4  // Make it circular

                    // Ensure button has a layer to add sublayers
                    if button.layer == nil {
                        button.wantsLayer = true
                        button.layer = CALayer()
                    }

                    button.layer?.addSublayer(badgeLayer)
                }
            }
        }

        /// Show the time left on an active elevation beside the tray icon.
        ///
        /// Set as the button's title rather than drawn into the image: the status item is
        /// variable-length, so the text lays out beside the icon on its own, and `updateTrayIcon`
        /// rebuilds the image and its layers without disturbing it.
        func updateElevationCountdown(remaining: TimeInterval) {
            guard let button = statusItem.button else { return }

            guard remaining > 0 else {
                button.title = ""
                button.toolTip = nil
                return
            }

            button.title = " \(remaining.formattedTime())"
            button.toolTip = Constants.General.demote
        }

        func getStatusItem() -> NSStatusItem {
            return statusItem
        }
    }

    @objc private func togglePopover() {
        guard let button = trayManager.getStatusItem().button else {
            Logger.shared.logError("Error: TrayMenuManager's statusItem.button is nil")
            return
        }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            // Dynamically set the popover content
            popover.contentViewController = NSHostingController(
                rootView: TrayMenuView(
                    viewModel: CardGridViewModel(appState: AppStateManager.shared)
                )
                .environment(AppStateManager.shared)
            )

            // Anchor the popover to the status item's button
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Ensure the popover window is brought to the front
            if let popoverWindow = popover.contentViewController?.view.window {
                popoverWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }

            installPopoverEventMonitors()
        }
    }

    private func installPopoverEventMonitors() {
        removePopoverEventMonitors()

        // Another of this app's windows taking focus, e.g. the main window opened from the popover
        popoverKeyWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self, let window = notification.object as? NSWindow else { return }
                if window !== self.popover.contentViewController?.view.window {
                    self.closePopover()
                }
            }
        }

        // Clicks in other apps
        if let globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown],
            handler: { [weak self] _ in
                Task { @MainActor in self?.closePopover() }
            })
        {
            popoverEventMonitors.append(globalMonitor)
        }

        // Clicks in this app's other windows, and Escape
        if let localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown],
            handler: { [weak self] event in
                guard let self else { return event }
                if event.type == .keyDown {
                    if event.keyCode == 53 {  // Escape
                        self.closePopover()
                        return nil
                    }
                    return event
                }
                let popoverWindow = self.popover.contentViewController?.view.window
                let statusItemWindow = self.trayManager.getStatusItem().button?.window
                // Clicks on the status item are left to togglePopover
                if event.window !== popoverWindow && event.window !== statusItemWindow {
                    self.closePopover()
                }
                return event
            })
        {
            popoverEventMonitors.append(localMonitor)
        }
    }

    private func removePopoverEventMonitors() {
        popoverEventMonitors.forEach { NSEvent.removeMonitor($0) }
        popoverEventMonitors.removeAll()
        if let popoverKeyWindowObserver {
            NotificationCenter.default.removeObserver(popoverKeyWindowObserver)
            self.popoverKeyWindowObserver = nil
        }
    }

    private func closePopover() {
        if popover.isShown {
            popover.performClose(nil)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        Logger.shared.logDebug("Popover closed, cleaning up...")
        removePopoverEventMonitors()

        // Cleanup logic: release the popover or its content
        popover.contentViewController = nil
    }

    @objc func showWindow() {
        if windowController == nil {
            NSApp.setActivationPolicy(.regular)
            let contentView = ContentView()
                .environment(AppStateManager.shared)
                .environment(AppStateManager.shared.preferences)
                .frame(minWidth: 1100, minHeight: 650)

            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 1500, height: 1020))
            window.styleMask = [.titled, .closable, .resizable]
            window.minSize = NSSize(width: 1100, height: 650)
            window.title = ""
            window.isReleasedWhenClosed = false
            window.backgroundColor = .clear
            window.titlebarAppearsTransparent = true
            window.styleMask.insert(.fullSizeContentView)
            window.center()
            window.level = .normal

            // Assign a delegate to handle window lifecycle
            window.delegate = self

            windowController = NSWindowController(window: window)
        }

        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func runAction(_ sender: NSMenuItem) {
        guard let action = sender.representedObject as? Action else { return }
        Task {
            do {
                _ = try await ExecutionService.runAction(action)
            } catch {
                Logger.shared.logError("Tray menu action '\(action.name)' failed: \(error)")
            }
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func configureAppUpdateNotificationCommand() {
        guard let manager = appStateManager.activeUpdatesManager else { return }
        appStateManager.preferences.notifications.appUpdateNotificationCommand =
            "open \(manager.managementApp(forUpdates: true).path)"
    }
}

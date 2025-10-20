//
//  AppDelegate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import AppKit
import UserNotifications
import SwiftUI
import Combine

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
    private var cancellables: Set<AnyCancellable> = []
    private var trayManager: TrayMenuManager { TrayMenuManager.shared }

    @AppStorage("isDarkMode") private var isDarkMode: Bool = false

    var hasUpdatesAvailable: Bool {
        appStateManager.pendingUpdatesCount > 0 || appStateManager.systemUpdateCache.count > 0
    }

    private func executeAction(_ action: Action) {
        Task {
            do {
                _ = try await ExecutionService.executeShellCommand(action.command, isPrivileged: action.isPrivileged)
            } catch {
                Logger.shared.logError("Failed to execute action: \(error)")
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }

        if url.host == "run" {
            Logger.shared.logDebug("Received run command request")
            if let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
                if let actionName = queryItems.first(where: { $0.name == "action" })?.value {
                    // Get the action details
                    if let action = appStateManager.preferences.actions.first(where: { $0.name == actionName }) {
                        Logger.shared.logDebug("Found action: \(action.name)")
                        if action.isPrivileged ?? false && appStateManager.preferences.requirePrivilegedActionAuthentication {
                            Logger.shared.logDebug("Action requires authentication") 
                            authenticateWithTouchIDOrPassword(completion: { success in
                                if success {
                                    self.executeAction(action)
                                } else {
                                    Logger.shared.logError("Authentication failed. Action: \(action.name) was not executed.")
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !AppDelegate.shouldExit && appStateManager.preferences.trayMenuShowIcon { 
            setupTrayMenu()
        }

        popover = NSPopover()
        popover.behavior = .transient // Closes when clicking outside
        popover.contentSize = NSSize(width: 500, height: 500)
        popover.contentViewController = NSHostingController(
            rootView: TrayMenuView(
                viewModel: CardGridViewModel(appState: AppStateManager.shared)
            )
            .environmentObject(AppStateManager.shared)
        )
        popover.delegate = self

        configureAppUpdateNotificationCommand(mode: appStateManager.preferences.mode)

        appStateManager.showWindowCallback = { [weak self] in
            self?.showWindow()
        }
        
        if appStateManager.preferences.showDesktopInfo {            
            // Initialize transparent window
            transparentWindowController = TransparentWindowController(appState: appStateManager)
            transparentWindowController?.showWindow(nil)
            
            // Make sure the transparent window is set up correctly
            if let window = NSApplication.shared.windows.first {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
        }
        
        requestNotificationPermissions()
        notificationDelegate = NotificationDelegate()
        UNUserNotificationCenter.current().delegate = notificationDelegate
        appStateManager.startBackgroundTasks()
        appStateManager.refreshAll()
        checkAndHandleDemotionOnLaunch()
    }

    private func checkAndHandleDemotionOnLaunch() {
    if let endTime = elevationManager.loadPersistedDemotionState(), Date() >= endTime {
        elevationManager.demotePrivileges { success in
                if success {
                    Logger.shared.logDebug("Privileges automatically demoted on app launch.")
                    // Clear persisted state
                    UserDefaults.standard.removeObject(forKey: "PrivilegeDemotionEndTime")
                } else {
                    Logger.shared.logError("Failed to demote privileges on app launch.")
                }
            }
    } else if let endTime = elevationManager.loadPersistedDemotionState() {
            let remainingTime = endTime.timeIntervalSinceNow
            elevationManager.startDemotionTimer(duration: remainingTime) { remainingTime in
                DispatchQueue.main.async {
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
        Publishers.CombineLatest4(
            appStateManager.$pendingUpdatesCount,
            appStateManager.$systemUpdateCache,
            appStateManager.preferences.$hiddenActions,
            appStateManager.preferences.$hiddenCards
        )
        .map { pendingUpdatesCount, systemUpdateCache, hiddenActions, hiddenCards in
            let hasPendingUpdates = !hiddenCards.contains("PendingAppUpdates") && pendingUpdatesCount > 0
            let hasSoftwareUpdates = !hiddenActions.contains("SoftwareUpdates") && systemUpdateCache.count > 0
            return hasPendingUpdates || hasSoftwareUpdates
        }
            .sink { hasUpdates in
                TrayMenuManager.shared.updateTrayIcon(hasUpdates: hasUpdates)
            }
            .store(in: &cancellables)
    }

    class TrayMenuManager {
        static let shared = TrayMenuManager()
        let appStateManager = AppStateManager.shared
        let fileManager = FileManager.default
        private var statusItem: NSStatusItem

        private init() {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            updateTrayIcon(hasUpdates: false) // Default state
        }

        func updateTrayIcon(hasUpdates: Bool) {
            let iconName = "MenuIcon"
            let base64Logo = appStateManager.preferences.trayMenuBrandingIcon
            var showLogo = false
            var baseIcon: NSImage?

            showLogo = loadLogo(base64Logo: base64Logo)
            if showLogo {
                baseIcon = NSImage(data: Data(base64Encoded: base64Logo)!)
            } else {
                baseIcon = NSImage(named: iconName)
            }

            guard let baseIcon = baseIcon else {
                Logger.shared.logError("Error: Failed to load tray menu icon")
                return
            }

            baseIcon.size = NSSize(width: 16, height: 16)
            baseIcon.isTemplate = true // Ensure base icon respects system appearance

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
                        x: button.bounds.width - 15, // Align to the lower-right corner
                        y: 10, // Small offset from the bottom
                        width: 8,
                        height: 8
                    )
                    badgeLayer.cornerRadius = 4 // Make it circular
                    
                    // Ensure button has a layer to add sublayers
                    if button.layer == nil {
                        button.wantsLayer = true
                        button.layer = CALayer()
                    }
                    
                    button.layer?.addSublayer(badgeLayer)
                }
            }
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
                .environmentObject(AppStateManager.shared)
            )
            
            // Anchor the popover to the status item's button
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

            // Ensure the popover window is brought to the front
            if let popoverWindow = popover.contentViewController?.view.window {
                popoverWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func popoverDidClose(_ notification: Notification) {
        Logger.shared.logDebug("Popover closed, cleaning up...")
        
        // Cleanup logic: release the popover or its content
        popover.contentViewController = nil
    }

    @objc func showWindow() {
        if windowController == nil {
            NSApp.setActivationPolicy(.regular)
            let contentView = ContentView()
                .environmentObject(AppStateManager.shared)
                .environmentObject(AppStateManager.shared.preferences)
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
            _ = try await ExecutionService.executeShellCommand(action.command, isPrivileged: action.isPrivileged)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    private func configureAppUpdateNotificationCommand(mode: String) {
		if mode == Constants.modes.munki {
            appStateManager.preferences.appUpdateNotificationCommand = "open \(Constants.AppPaths.MSCUpdates)"
		} else if mode == Constants.modes.intune {
            appStateManager.preferences.appUpdateNotificationCommand = "open \(Constants.AppPaths.companyPortal)"
		} else if mode == Constants.modes.jamf {
			appStateManager.preferences.appUpdateNotificationCommand = "open \(Constants.AppPaths.selfService)"
		}
     }
}

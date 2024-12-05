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

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowController: NSWindowController?
    var transparentWindowController: TransparentWindowController?
    let appStateManager = AppStateManager.shared
    var mainWindow: NSWindow?
    static var urlLaunch = false
    private var notificationDelegate: NotificationDelegate?
    private var cancellables: Set<AnyCancellable> = []
    @AppStorage("isDarkMode") private var isDarkMode: Bool = false


    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        AppDelegate.urlLaunch = true
        showWindow()
        NotificationCenter.default.post(name: .handleIncomingURL, object: url)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupTrayMenu()
        let icon = NSImage(named: "MenuIcon")
        icon?.size = NSSize(width: 16, height: 16)
        statusItem?.button?.image = icon
        statusItem?.button?.image?.isTemplate = true
        
        appStateManager.refreshAll()
        configureAppUpdateNotificationCommand(mode: appStateManager.preferences.mode)
        
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
        
        appStateManager.preferences.$actions
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.setupTrayMenu()
            }
            .store(in: &cancellables)
        
    }

    private func setupTrayMenu() {
        // Initialize status item only if it doesn't already exist
        if statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            if let button = statusItem?.button {
                let icon = NSImage(named: "MenuIcon")
                icon?.size = NSSize(width: 16, height: 16)
                button.image = icon
                button.image?.isTemplate = true
            }
        }

        // Update the menu
        let menu = NSMenu()

        menu.addItem(NSMenuItem(title: Constants.TrayMenu.openApp, action: #selector(showWindow), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())

        // Create Actions submenu
        let actionsSubmenu = NSMenu()
        for action in appStateManager.preferences.actions {
            let actionItem = NSMenuItem(title: action.name, action: #selector(runAction), keyEquivalent: "")
            actionItem.representedObject = action
            actionsSubmenu.addItem(actionItem)
        }

        let actionsMenuItem = NSMenuItem(title: Constants.CardTitle.actions, action: nil, keyEquivalent: "")
        menu.setSubmenu(actionsSubmenu, for: actionsMenuItem)
        menu.addItem(actionsMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: Constants.TrayMenu.quitApp, action: #selector(quitApp), keyEquivalent: "q"))

        // Assign the updated menu to the status item
        statusItem?.menu = menu
    }

    @objc private func showWindow() {
        if windowController == nil {
            NSApp.setActivationPolicy(.regular)
            let contentView = ContentView()
                .environmentObject(AppStateManager.shared)
                .environmentObject(Preferences())
                .frame(minWidth: 1500, minHeight: 900)

            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(contentViewController: hostingController)
            window.setContentSize(NSSize(width: 1500, height: 900))
            window.styleMask = [.titled, .closable, .resizable]
            window.minSize = NSSize(width: 1500, height: 900)
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
        if mode == "Munki" {
            appStateManager.preferences.appUpdateNotificationCommand = "open \(Constants.AppPaths.MSCUpdates)"
        } else {
            appStateManager.preferences.appUpdateNotificationCommand = "open \(Constants.AppPaths.companyPortal)"
        }
    }
}

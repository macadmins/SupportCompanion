//
//  UserInstallManager.swift
//  SupportCompanion
//

import AppKit
import Foundation
import Observation
import SwiftUI

/// Drives the window a user sees after opening an installer.
///
/// Every decision here is the helper's, fetched once by staging the file. This object knows whether to
/// show a window, what to put in it, and what to do when a button is pressed — it does not decide
/// whether anything may be installed, and its view of the allowlist is not consulted anywhere.
@MainActor
@Observable
final class UserInstallManager {

    static let shared = UserInstallManager()

    enum Stage: Equatable {
        case assessing(fileName: String)
        case allowed(InstallerAssessment)
        case refused(InstallerAssessment)
        case installing(InstallerAssessment)
        case installed(InstallerAssessment)
        case failed(assessment: InstallerAssessment?, message: String)
    }

    private(set) var stage: Stage?

    @ObservationIgnored private var url: URL?
    @ObservationIgnored private var window: NSWindow?

    private init() {}

    // MARK: Opening

    /// Take over an installer the user opened.
    ///
    /// Anything that goes wrong here hands the file back to the system rather than stopping: a Mac
    /// where installers cannot be opened at all would be a far worse outcome than one where this
    /// feature is not helping.
    func open(_ url: URL) {
        guard AppStateManager.shared.preferences.enableUserInstalls else {
            // Said out loud: this used to be the quietest of three ways to end up back in
            // Installer.app, which made a misconfigured feature look exactly like a working one.
            Logger.shared.logInfo(
                "EnableUserInstalls is not set, so \(url.lastPathComponent) goes to the system handler"
            )
            handOffToSystem(url)
            return
        }

        self.url = url
        stage = .assessing(fileName: url.lastPathComponent)
        showWindow()

        Task {
            do {
                let assessment = try await ExecutionService.stageInstaller(at: url)

                if assessment.isAllowed {
                    stage = .allowed(assessment)
                    return
                }

                Logger.shared.logInfo(
                    "\(url.lastPathComponent) is not allowed by an administrator: \(assessment.rejectionReasons.joined(separator: "; "))"
                )

                // Always said out loud, whatever the fallback is. Handing the file quietly to
                // Installer.app leaves someone who cannot type an administrator password staring at a
                // prompt, with the actual reason sitting in a log only root can read. The fallback
                // decides which way out is offered, not whether the user is told anything.
                stage = .refused(assessment)
            } catch {
                // Not a silent hand-off. The helper is the only thing that can answer this question,
                // and if it did not, the user is about to be asked for an administrator password they
                // do not have — so say why, and leave them the same button they would have had.
                Logger.shared.logError("Unable to assess \(url.lastPathComponent): \(error.localizedDescription)")
                stage = .failed(assessment: nil, message: error.localizedDescription)
            }
        }
    }

    /// Open the file the way the system would if this app were not on the Mac.
    private func handOffToSystem(_ url: URL) {
        let handler: String

        switch url.pathExtension.lowercased() {
        case "dmg":
            handler = "/System/Library/CoreServices/DiskImageMounter.app"
        default:
            handler = "/System/Library/CoreServices/Installer.app"
        }

        guard FileManager.default.fileExists(atPath: handler) else {
            NSWorkspace.shared.open(url)
            return
        }

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: URL(fileURLWithPath: handler),
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, error in
            if let error {
                Logger.shared.logError("Unable to hand \(url.lastPathComponent) to \(handler): \(error.localizedDescription)")
            }
        }
    }

    // MARK: Installing

    func install() {
        guard case .allowed(let assessment) = stage, let token = assessment.token else { return }

        guard assessment.requiresAuthentication else {
            performInstall(assessment, token: token)
            return
        }

        // The point of the feature is that no administrator password is typed. Replacing that with
        // nothing would make an unlocked Mac enough, so the user confirms with their own credentials.
        authenticateWithTouchIDOrPassword(
            completion: { [weak self] success in
                Task { @MainActor in
                    guard let self else { return }

                    guard success else {
                        Logger.shared.logError("Authentication failed; \(assessment.facts.fileName) was not installed")
                        self.cancel()
                        return
                    }

                    self.performInstall(assessment, token: token)
                }
            },
            reason: "authenticate to install \(assessment.facts.displayName ?? assessment.facts.fileName)"
        )
    }

    private func performInstall(_ assessment: InstallerAssessment, token: String) {
        stage = .installing(assessment)

        Task {
            do {
                let output = try await ExecutionService.installStagedInstaller(token: token)
                Logger.shared.logInfo("Installed \(assessment.facts.fileName): \(output)")
                stage = .installed(assessment)
            } catch {
                Logger.shared.logError("Failed to install \(assessment.facts.fileName): \(error.localizedDescription)")
                stage = .failed(assessment: assessment, message: error.localizedDescription)
            }
        }
    }

    // MARK: The supported route

    /// Whether the organisation already offers what the user just tried to install.
    ///
    /// Asked of `activeUpdatesManager`, so it answers for whichever mode is configured and this knows
    /// nothing about any of them. A mode with no catalog returns nil and nothing is offered.
    func catalogSuggestion(for facts: InstallerFacts) -> CatalogSuggestion? {
        AppStateManager.shared.activeUpdatesManager?.catalogSuggestion(for: facts)
    }

    /// Send the user where the approved copy lives.
    ///
    /// The destination is whatever the mode's `managementApp` reports, which is this app's own Apps
    /// page for Fleet and a separate application for Munki or Jamf — so both shapes are handled here
    /// rather than assumed.
    func showCatalog(_ suggestion: CatalogSuggestion) {
        closeWindow()

        let path = suggestion.destinationPath

        if path.hasPrefix("supportcompanion://") {
            AppStateManager.shared.showWindowCallback?()

            if let url = URL(string: path) {
                NotificationCenter.default.post(name: .handleIncomingURL, object: url)
            }

            return
        }

        // A scheme of somebody else's, such as Munki's munki://updates.html, or a path on disk.
        if let url = URL(string: path), url.scheme != nil {
            NSWorkspace.shared.open(url)
        } else if !path.isEmpty {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    // MARK: Fallbacks

    /// Offer the existing time-limited elevation instead, for an installer nobody allowed.
    ///
    /// `ElevationManager.shared`, never a fresh one: `handleElevation` returns as soon as it has asked
    /// for authentication, and its completion holds the manager weakly. A manager owned by this method
    /// is released the moment the method returns, and everything after the user authenticates —
    /// logging the reason, and starting the countdown the UI reads — is silently skipped.
    func elevate() {
        guard let url else { return }

        let appState = AppStateManager.shared

        closeWindow()

        if appState.preferences.elevation.requireReasonForElevation {
            ReasonInputManager.shared.presentAsWindow(isPresented: .constant(true)) { reason in
                ElevationManager.shared.handleElevation(reason: reason) { granted in
                    Self.finishElevation(granted: granted, for: url)
                }
            }
        } else {
            ElevationManager.shared.handleElevation(reason: "") { granted in
                Self.finishElevation(granted: granted, for: url)
            }
        }
    }

    /// Hand the installer back once the rights it needed exist.
    ///
    /// Only after the grant. Opening it any earlier — which is what happened while this ran alongside
    /// the reason prompt — puts the file in front of someone who still cannot install it.
    @MainActor
    private static func finishElevation(granted: Bool, for url: URL) {
        guard granted else {
            Logger.shared.logError("Elevation was not granted; \(url.lastPathComponent) was not reopened")
            return
        }

        Logger.shared.logInfo("Elevation granted, reopening \(url.lastPathComponent)")
        shared.handOffToSystem(url)
    }

    func openInInstaller() {
        guard let url else { return }
        closeWindow()
        handOffToSystem(url)
    }

    // MARK: Dismissal

    func cancel() {
        if let token = currentToken {
            Task { try? await ExecutionService.discardStagedInstaller(token: token) }
        }

        closeWindow()
    }

    private var currentToken: String? {
        switch stage {
        case .allowed(let assessment), .refused(let assessment):
            return assessment.token
        default:
            return nil
        }
    }

    // MARK: Window

    private func showWindow() {
        guard window == nil else {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: UserInstallView(manager: self)
                .environment(AppStateManager.shared)
        )

        let newWindow = NSWindow(contentViewController: controller)
        newWindow.setContentSize(NSSize(width: 520, height: 400))
        newWindow.styleMask = [.titled, .closable, .fullSizeContentView]
        newWindow.titlebarAppearsTransparent = true
        newWindow.title = ""
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.level = .floating

        window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeWindow() {
        stage = nil
        url = nil
        window?.orderOut(nil)
        window?.close()
        window = nil
    }
}

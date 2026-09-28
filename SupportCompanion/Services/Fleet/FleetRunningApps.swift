//
//  FleetRunningApps.swift
//  SupportCompanion
//
//  Which Fleet titles are open on this Mac, for installs that can't run while their app is open.
//

import AppKit
import Observation

@MainActor
@Observable
final class FleetRunningApps {
    static let shared = FleetRunningApps()

    private(set) var runningBundleIDs: Set<String> = []

    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        update()
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
        ] {
            observers.append(
                center.addObserver(forName: name, object: nil, queue: .main) { _ in
                    MainActor.assumeIsolated { FleetRunningApps.shared.update() }
                })
        }
    }

    func isRunning(_ title: FleetSoftwareTitle) -> Bool {
        !runningBundleIDs.isDisjoint(with: title.bundleIdentifiers)
    }

    /// Asks the title's app to quit, as if the user chose Quit, and waits up to `timeout` for it to exit.
    /// Returns false if it's still open, e.g. because the user cancelled a prompt to save changes, or if
    /// Fleet doesn't know the app's bundle identifier, so it can't be found.
    func quit(_ title: FleetSoftwareTitle, timeout: TimeInterval = 30) async -> Bool {
        guard !title.bundleIdentifiers.isEmpty else { return false }
        let apps = title.bundleIdentifiers.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        }
        apps.forEach { $0.terminate() }
        let deadline = Date().addingTimeInterval(timeout)
        while apps.contains(where: { !$0.isTerminated }), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(500))
        }
        update()
        return apps.allSatisfy(\.isTerminated)
    }

    private func update() {
        let ids = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        if ids != runningBundleIDs {
            runningBundleIDs = ids
        }
    }
}

/// Recognizes install script output that says the app has to be closed first.
///
/// Fleet-maintained apps with "patch when closed" are flagged by Fleet itself. Custom packages can only
/// say so in their install script's output, so this matches that output against phrases, case-insensitively.
/// `FleetAppOpenMessages` (array of strings) replaces the built-in phrases, e.g. with the exact message your
/// scripts print; an empty array turns detection off for custom packages.
struct FleetAppOpenMessages {
    static let defaults = [
        "must be closed", "must be quit", "needs to be closed", "needs to be quit",
        "app is running", "app is open", "app was open",
        "quit the app", "close the app",
    ]

    let phrases: [String]

    @MainActor static var current: FleetAppOpenMessages {
        FleetAppOpenMessages(
            phrases: DefaultsStore.optionalValue(forKey: "FleetAppOpenMessages") ?? defaults)
    }

    func matches(_ output: String) -> Bool {
        phrases.contains { !$0.isEmpty && output.localizedCaseInsensitiveContains($0) }
    }
}

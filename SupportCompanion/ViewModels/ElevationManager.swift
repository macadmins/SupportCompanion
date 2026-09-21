import Foundation
import Combine
import SwiftUI

/// Drives the elevation UI.
///
/// The helper owns temporary administrator rights: it decides whether elevation is allowed, records the
/// deadline in a root-owned file, and takes the rights back when the time is up. The timer here only
/// drives the countdown and the halfway notification, so quitting the app no longer leaves the user an
/// administrator — it just stops the display.
@MainActor
class ElevationManager {
    private var elevationReason = ""
    private var appState: AppStateManager
    private var cancellable: AnyCancellable?
    private var timerPublisher: AnyPublisher<Date, Never>?
    private var onTimeUpdate: ((Double) -> Void)?

    static let shared = ElevationManager(appState: AppStateManager.shared)

    init(appState: AppStateManager) {
        self.appState = appState
    }

    func elevatePrivileges(reason: String, completion: @escaping (Bool) -> Void) {
        authenticateWithTouchIDOrPassword(completion: { success in
            guard success else {
                completion(false)
                return
            }
            Task {
                do {
                    // The helper re-checks EnableElevation before doing anything, and throws if an
                    // administrator has not turned elevation on.
                    _ = try await ExecutionService.elevate(reason: reason)
                    UserInfoManager.shared.updateUserInfo()
                    completion(true)
                }
                catch {
                    Logger.shared.logError("Failed to elevate privileges: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }, reason: "authenticate to elevate privileges")
    }

    func demotePrivileges(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                _ = try await ExecutionService.demote()
                // Update isAdmin status
                UserInfoManager.shared.updateUserInfo()
                completion(true)
            }
            catch {
                Logger.shared.logError("Failed to demote privileges: \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    /// Seconds until the helper demotes the user, as the helper sees it.
    func remainingElevationTime() async -> TimeInterval {
        do {
            return try await ExecutionService.elevationTimeRemaining()
        } catch {
            Logger.shared.logError("Failed to read elevation time remaining: \(error.localizedDescription)")
            return 0
        }
    }

    func startDemotionTimer(duration: TimeInterval, onUpdate: @escaping (Double) -> Void) {
        Logger.shared.logDebug("Starting demotion timer with duration: \(duration)")
        stopDemotionTimer() // Ensure any existing timer is stopped

        NotificationService(appState: self.appState).sendNotification(
            message: "\(Constants.Notifications.Elevation.ElevationStartedMessage) \(duration.formattedTimeUnit()).", 
            notificationType: .generic
        )

        var remainingTime = duration
        self.onTimeUpdate = onUpdate

        // Create a Combine Timer Publisher
        timerPublisher = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()

        // Subscribe to timer updates
        cancellable = timerPublisher?.sink { [weak self] _ in
            guard let self = self else { return }

            if remainingTime > 0 {
                remainingTime -= 1
                var timeToDemote = appState.timeToDemote
                timeToDemote -= 1
                // If half the time has passed, notify the user
                if remainingTime == duration / 2 {
                    NotificationService(appState: self.appState).sendNotification(
                        message: "\(Constants.Notifications.Elevation.ElevationHalfwayMessage) \(timeToDemote.formattedTimeUnit()).",
                        buttonText: Constants.General.demote,
                        command: "demote",
                        notificationType: .generic
                    )
                }
                self.onTimeUpdate?(remainingTime)
            } else {
                self.stopDemotionTimer()

                // The helper demotes on its own schedule; catch up with what it did rather than
                // asking for a second demotion.
                Task { @MainActor in
                    UserInfoManager.shared.updateUserInfo()
                    NotificationService(appState: self.appState).sendNotification(
                        message: Constants.Notifications.Elevation.ElevationDemotedMessage,
                        notificationType: .generic
                    )
                }
                Logger.shared.logDebug("Demotion timer expired.")
            }
        }
    }

    /// Stops the timer
    func stopDemotionTimer() {
        cancellable?.cancel()
        cancellable = nil
        onTimeUpdate?(0) // Notify remaining time is 0
    }

    func handleElevation(reason: String) {
        Logger.shared.logDebug("Handling elevation for reason: \(reason)")
        // Authenticate and elevate privileges
        self.elevatePrivileges(reason: reason) { success in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard success else {
                    Logger.shared.logDebug("Authentication failed or elevation was refused.")
                    return
                }
                Logger.shared.logDebug("Privileges elevated.")
                if self.appState.preferences.elevation.requireReasonForElevation {
                    if !self.appState.preferences.elevation.elevationWebhookURL.isEmpty {
                        sendReasonToWebhook(reason: reason)
                    } else {
                        saveReasonToDisk(reason: reason)
                    }
                }
                // Count down from what the helper actually granted, not from what we asked for
                let duration = await self.remainingElevationTime()
                self.appState.startDemotionTimer(duration: duration)
            }
        }
    }
}

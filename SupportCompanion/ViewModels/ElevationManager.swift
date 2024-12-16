import Foundation
import Combine
import SwiftUI

class ElevationManager {
    @State private var elevationReason = ""
    private var appState: AppStateManager
    private var cancellable: AnyCancellable?
    private var timerPublisher: AnyPublisher<Date, Never>?
    private var onTimeUpdate: ((Double) -> Void)?

    static let shared = ElevationManager(appState: AppStateManager.shared)

    init(appState: AppStateManager) {
        self.appState = AppStateManager.shared
    }

        func elevatePrivileges(completion: @escaping (Bool) -> Void) {
        authenticateWithTouchIDOrPassword { success in
            guard success else {
                completion(false)
                return
            }
            let command = "/usr/sbin/dseditgroup"
            let arguments = ["-o", "edit", "-a", NSUserName(), "-t", "user", "admin"]
            Task {
                do {
                    _ = try await ExecutionService.executeCommandPrivileged(command, arguments: arguments)
                    // Update isAdmin status
                    UserInfoManager.shared.updateUserInfo()
                    completion(true)
                }
                catch {
                    Logger.shared.logError("Failed to elevate privileges: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }

    func demotePrivileges(completion: @escaping (Bool) -> Void) {
        let command = "/usr/sbin/dseditgroup"
        let arguments = ["-o", "edit", "-d", NSUserName(), "-t", "user", "admin"]
        Task {
            do {
                _ = try await ExecutionService.executeCommandPrivileged(command, arguments: arguments)
                // Update isAdmin status
                UserInfoManager.shared.updateUserInfo()
                UserDefaults.standard.removeObject(forKey: "PrivilegeDemotionEndTime")
                completion(true)
            }
            catch {
                Logger.shared.logError("Failed to demote privileges: \(error.localizedDescription)")
                completion(false)
            }
        }
    }

    func startDemotionTimer(duration: TimeInterval, onUpdate: @escaping (Double) -> Void) {
        Logger.shared.logDebug("Starting demotion timer with duration: \(duration)")
        stopDemotionTimer() // Ensure any existing timer is stopped

        persistDemotionState(endTime: Date().addingTimeInterval(duration))

        NotificationService(appState: self.appState).sendNotification(
            message: "Privliged session started. You will be demoted in \(duration.formattedTimeUnit()).", 
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
                        message: "Your elevated privileges will be demoted in \(timeToDemote.formattedTimeUnit()).",
                        notificationType: .generic
                    )
                }
                self.onTimeUpdate?(remainingTime)
            } else {
                self.stopDemotionTimer()
                self.demotePrivileges { success in
                    guard success else {
                        Logger.shared.logDebug("Failed to demote privileges.")
                        return
                    }
                    NotificationService(appState: self.appState).sendNotification(
                        message: "Your elevated privileges have been demoted.",
                        notificationType: .generic
                    )
                }
                Logger.shared.logDebug("Demotion timer expired. Privileges demoted.")
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
        self.elevatePrivileges { success in
            guard success else {
                Logger.shared.logDebug("Authentication failed. Unable to elevate privileges.")
                return
            }
            Logger.shared.logDebug("Authentication successful. Privileges elevated.")
            if self.appState.preferences.requireReasonForElevation {
                if !self.appState.preferences.elevationWebhookURL.isEmpty {
                    sendReasonToWebhook(reason: reason)
                } else {
                    saveReasonToDisk(reason: reason)
                }
            }
            // Start the timer
            self.appState.startDemotionTimer(duration: self.appState.preferences.maxElevationTime)
        }
    }

    func persistDemotionState(endTime: Date) {
        UserDefaults.standard.set(endTime, forKey: "PrivilegeDemotionEndTime")
        UserDefaults.standard.synchronize()
    }

    func loadPersistedDemotionState() -> Date? {
        return UserDefaults.standard.object(forKey: "PrivilegeDemotionEndTime") as? Date
    }
}

import Foundation
import Combine
import SwiftUI

class CardGridViewModel: ObservableObject {
    @Published var toastConfig: ToastConfig?
    private let appState: AppStateManager
    private let munkiApps = MunkiApps()
    var installPercentageTimer: Timer?
    var pendingAppsTimer: Timer?
    private var fetchTask: Task<Void, Never>?
    private var isTaskRunning = false
    private var isPendingAppsTaskRunning = false
    
    init(appState: AppStateManager) {
        self.appState = appState
    }
    
    // MARK: - Device Information Helpers
    private var healthPercentage: Int {
        if appState.batteryInfoManager.batteryInfo.designCapacity > 0 {
            return Int(round((Double(appState.batteryInfoManager.batteryInfo.maxCapacity) / Double(appState.batteryInfoManager.batteryInfo.designCapacity)) * 100))
        } else {
            return 0
        }
    }

    var deviceInfo: [(String, Any)] {
            [
                ("--------------------- Device ---------------------", ""),
                ("Host Name:", appState.deviceInfoManager.deviceInfo?.hostName ?? ""),
                ("Serial Number:", appState.deviceInfoManager.deviceInfo?.serialNumber ?? ""),
                ("Model:", appState.deviceInfoManager.deviceInfo?.model ?? ""),
                ("Processor:", appState.deviceInfoManager.deviceInfo?.cpuType ?? ""),
                ("Memory:", appState.deviceInfoManager.deviceInfo?.ram ?? ""),
                ("OS Version:", appState.deviceInfoManager.deviceInfo?.osVersion ?? ""),
                ("OS Build:", appState.deviceInfoManager.deviceInfo?.osBuild ?? ""),
                ("IP Address:", appState.deviceInfoManager.deviceInfo?.ipAddress ?? ""),
                ("WiFi SSID:", appState.deviceInfoManager.deviceInfo?.ssid ?? ""),
                ("Last Reboot:", "\(appState.deviceInfoManager.deviceInfo?.lastRestartDays ?? 0) days"),
                ("--------------------- Battery ---------------------", ""),
                ("Health:", "\(healthPercentage)%"),
                ("Cycle Count:", appState.batteryInfoManager.batteryInfo.cycleCount),
                ("Temperature:", "\((String(format: "%.1f", appState.batteryInfoManager.batteryInfo.temperature)))°C"),
                ("--------------------- Storage ---------------------", ""),
                ("Used:", "\(appState.storageInfoManager.storageInfo.usage)%"),
                ("FileVault:", appState.storageInfoManager.storageInfo.fileVault ? "Enabled" : "Disabled"),

            ]
        }
    
    func createRestartIntuneAgentButton(fontSize: CGFloat? = nil) -> ScButton {
        ScButton(Constants.Actions.restartIntuneAgent, fontSize: fontSize) {
            ActionHelpers.restartIntuneAgent { result in
                ActionHelpers.handleResult(
                    operationName: "Restart Intune Agent",
                    result: result,
                    successMessage: "Intune agent was restarted successfully.",
                    //errorMessage: "Failed to restart Intune agent",
                    updateToast: { toast in
                        DispatchQueue.main.async {
                            self.toastConfig = toast
                        }
                    }
                )
            }
        }
    }
    
    func createGatherLogsButton(fontSize: CGFloat? = nil) -> ScButton {
        ScButton(Constants.Actions.gatherLogs, fontSize: fontSize) {
            ActionHelpers.gatherLogs(preferences: self.appState.preferences) { result in
                ActionHelpers.handleResult(
                    operationName: Constants.Actions.gatherLogs,
                    result: result,
                    successMessage: Constants.ToastMessages.SuccessMessages.gatherLogsSuccess,
                    updateToast: { toast in
                        DispatchQueue.main.async {
                            self.toastConfig = toast
                        }
                    }
                )
            }
        }
    }
    
    func createRebootButton(
        onShowModal: @escaping (Int, String, String) -> Void
    ) -> ScButton {
        ScButton(Constants.Actions.reboot) {
            await ActionHelpers.reboot { result in
                DispatchQueue.main.async {
                    switch result {
                    case .info(let message):
                        onShowModal(Constants.RebootModal.countdown, Constants.RebootModal.title, message) // Trigger modal
                    case .failure(let error):
                        Logger.shared.logError("Reboot failed: \(error.localizedDescription)")
                    default:
                        break
                    }
                }
            }
        }
    }
    
    func createChangePasswordButton(fontSize: CGFloat? = nil) -> ScButton {
        ScButton(Constants.Actions.changePassword, fontSize: fontSize) {
            await ActionHelpers.openChangePassword(preferences: self.appState.preferences) { result in
                ActionHelpers.handleResult(
                    operationName: Constants.Actions.changePassword,
                    result: result,
                    successMessage: "",
                    updateToast: { toast in
                        DispatchQueue.main.async {
                            self.toastConfig = toast
                        }
                    }
                )
            }
        }
    }
    
    enum ManagementAppURLType {
        case update
        case `default`
    }
    
    func createOpenManagementAppButton(type: ManagementAppURLType, fontSize: CGFloat? = nil) -> ScButton {
        let appName: String
        let appURL: String

        switch appState.preferences.mode {
        case Constants.modes.munki:
            if type == .update {
                appName = "MSC Updates"
                appURL = Constants.AppPaths.MSCUpdates
            } else {
                appName = "MSC"
                appURL = Constants.AppPaths.MSC
            }
        case Constants.modes.intune:
            appName = "Company Portal"
            appURL = Constants.AppPaths.companyPortal
		case Constants.modes.jamf:
			appName = "Self Service"
			appURL = Constants.AppPaths.selfService
        default:
            appName = "Unknown App"
            appURL = ""
        }

        return ScButton("\(Constants.Actions.openManagementApp) \(appName)", fontSize: fontSize) {
            ActionHelpers.openManagementApp(appURL: appURL)
        }
    }
        
    func copyDeviceInfoToClipboard() {
        let clipboardContent = deviceInfo
            .map { "\($0.0) \($0.1)" }
            .joined(separator: "\n")
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let didWrite = pasteboard.setString(clipboardContent, forType: .string)
        
        if didWrite, let _ = pasteboard.string(forType: .string) {
            DispatchQueue.main.async {
                self.toastConfig = ToastConfig(
                    isShowing: true,
                    type: .complete(.green),
                    title: "Success!",
                    subTitle: "Device info copied to clipboard."
                )
            }
        }
        else {
            DispatchQueue.main.async {
                self.toastConfig = ToastConfig(
                    isShowing: true,
                    type: .error(.red),
                    title: "Error!",
                    subTitle: "Failed to copy device info."
                )
            }
        }
    }
    
    func openStoragePanel() {
        Task {
            do {
                _ = try await ExecutionService.executeCommand("open", with: [Constants.Panels.storage])
            }
        }
    }

    func fileVaultTextColor() -> Color {
        appState.storageInfoManager.storageInfo.fileVault ? .ScGreen : Color.orange
    }
    
    // MARK: - Preferences Management
    
    func isCardVisible(_ card: String) -> Bool {
        !appState.preferences.hiddenCards.contains(card)
    }

    // MARK: - Buttons
    func isButtonVisible(_ button: String) -> Bool {
        !appState.preferences.hiddenActions.contains(button)
    }
	
	@Published var isUpdating = false

	func runJamfUpdate(forId: String) async {
		await MainActor.run { self.isUpdating = true }
		defer { Task { await MainActor.run { self.isUpdating = false } } }

		// Kick off the update; ideally obtain a process handle or PID
		do {
			_ = try await ExecutionService.executeCommandPrivileged(
				"/usr/local/bin/jamf",
				arguments: ["patch", "-id", forId]
			)
		} catch {
			// Log and bail
			Logger.shared.logError("jamf patch launch failed: \(error)")
			return
		}

		// Poll conservatively with delay; add timeout
		let pattern = "jamf patch -id \(forId)"
		let deadline = Date().addingTimeInterval(600) // 10 min timeout

		while Date() < deadline && !Task.isCancelled {
			do {
				let result = try await ExecutionService.executeCommand(
					"/usr/bin/pgrep",
					with: ["-lf", pattern]
				)
				if result.isEmpty {
					break // process no longer running
				}
			} catch {
				// If pgrep errors, consider breaking or retrying a few times
				Logger.shared.logError("pgrep error: \(error)")
			}

			try? await Task.sleep(for: .seconds(0.5))
		}
	}
}

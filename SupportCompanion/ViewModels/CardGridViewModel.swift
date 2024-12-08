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
    
    var deviceInfo: [(String, Any)] {
            [
                ("Host Name:", appState.deviceInfoManager.deviceInfo?.hostName ?? ""),
                ("Serial Number:", appState.deviceInfoManager.deviceInfo?.serialNumber ?? ""),
                ("Model:", appState.deviceInfoManager.deviceInfo?.model ?? ""),
                ("Processor:", appState.deviceInfoManager.deviceInfo?.cpuType ?? ""),
                ("Memory:", appState.deviceInfoManager.deviceInfo?.ram ?? ""),
                ("OS Version:", appState.deviceInfoManager.deviceInfo?.osVersion ?? ""),
                ("OS Build:", appState.deviceInfoManager.deviceInfo?.osBuild ?? ""),
                ("IP Address:", appState.deviceInfoManager.deviceInfo?.ipAddress ?? ""),
                ("Last Reboot:", "\(appState.deviceInfoManager.deviceInfo?.lastRestart ?? 0) days")
            ]
        }
    
    func createRestartIntuneAgentButton(fontSize: CGFloat? = nil) -> CustomButton {
        CustomButton(Constants.Actions.restartIntuneAgent, fontSize: fontSize) {
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
    
    func createGatherLogsButton(fontSize: CGFloat? = nil) -> CustomButton {
        CustomButton(Constants.Actions.gatherLogs, fontSize: fontSize) {
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
    ) -> CustomButton {
        CustomButton(Constants.Actions.reboot) {
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
    
    func createChangePasswordButton(fontSize: CGFloat? = nil) -> CustomButton {
        CustomButton(Constants.Actions.changePassword, fontSize: fontSize) {
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
    
    func createOpenManagementAppButton(type: ManagementAppURLType, fontSize: CGFloat? = nil) -> CustomButton {
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
        default:
            appName = "Unknown App"
            appURL = ""
        }

        return CustomButton("\(Constants.Actions.openManagementApp) \(appName)", fontSize: fontSize) {
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
        
        if didWrite, let retrievedContent = pasteboard.string(forType: .string) {
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
        appState.storageInfoManager.storageInfo.fileVault ? Color.green : Color.orange
    }
    
    // MARK: - Preferences Management
    
    func isCardVisible(_ card: String) -> Bool {
        !appState.preferences.hiddenCards.contains(card)
    }

    // MARK: - Buttons
    func isButtonVisible(_ button: String) -> Bool {
        !appState.preferences.hiddenActions.contains(button)
    }
}

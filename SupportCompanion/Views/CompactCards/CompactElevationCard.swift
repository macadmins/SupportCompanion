import Foundation
import SwiftUI

struct CompactElevationCard: View {
    @Environment(AppStateManager.self) var appState
    @State private var showReasonInput = false

    var body: some View {
        ScCardCompact(
            title: Constants.CardTitle.privileges,
            titleImageName: "lock.fill",
            imageSize: (13, 13),
            content: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Revocation in: ")
                            .bold()
                            .font(.system(size: 12))
                        if appState.timeToDemote > 0 {
                            Text(appState.timeToDemote.formattedTime())
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                        }
                    }

                    Spacer()
                    
                    HStack {
                        ScSmallButton(
                            Constants.General.elevate,
                            disabled: appState.userInfoManager.userInfo.isAdmin || appState.isDemotionActive
                        ) {
                            if appState.preferences.elevation.requireReasonForElevation {
                                ReasonInputManager.shared.presentAsWindow(
                                    isPresented: $showReasonInput,
                                    onElevate: { reason in
                                        ElevationManager.shared.handleElevation(reason: reason)
                                    }
                                )
                            } else {
                                ElevationManager.shared.handleElevation(reason: "")
                            }
                        }

                        ScSmallButton(Constants.General.demote, disabled: !appState.isDemotionActive) {
                            appState.stopDemotionTimer()
                            ElevationManager.shared.demotePrivileges { success in
                                if success {
                                    Logger.shared.logDebug("Successfully demoted privileges")
                                } else {
                                    Logger.shared.logError("Failed to demote privileges")
                                }
                            }
                        }
                    }
                }
            }
        )
    }
}

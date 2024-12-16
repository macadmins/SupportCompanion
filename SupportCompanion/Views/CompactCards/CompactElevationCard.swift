import Foundation
import SwiftUI

struct CompactElevationCard: View {
    @EnvironmentObject var appState: AppStateManager
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

                    Button(action: {
                        if appState.preferences.requireReasonForElevation {
                            ReasonInputManager.shared.presentAsWindow(
                                isPresented: $showReasonInput,
                                onElevate: { reason in
                                    ElevationManager.shared.handleElevation(reason: reason)
                                }
                            )
                        } else {
                            ElevationManager.shared.handleElevation(reason: "")
                        }
                    }) {
                        VStack {
                            ButtonTitle(title: Constants.General.elevate, fontSize: 12, isLoading: false)
                        }
                        .padding(8)
                        .background(Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(appState.userInfoManager.userInfo.isAdmin || appState.isDemotionActive)
                }
            }
        )
    }
}

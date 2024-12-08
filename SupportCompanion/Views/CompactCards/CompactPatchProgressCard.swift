import Foundation
import SwiftUI

struct CompactPatchProgressCard: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        CustomCardCompact(
            title: "Patch progress",
            titleImageName: "app",
            buttonImageName: "info.circle",
            buttonAction: {},
            imageSize: (13, 13),
            content: {
                HStack {
                    Text("Progress: ")
                        .bold()
                        .font(.system(size: 12))
                    + Text("\(Int(appState.installPercentage))")
                        .font(.system(size: 12))
                        .foregroundColor(
                            appState.installPercentage < 90 ? (colorScheme == .light ? .orangeLight : .orange)
                            : appState.installPercentage < 60 ? (colorScheme == .light ? .redLight : .red)
                            : .green)
                    + Text("%")
                        .font(.system(size: 12))
                }
                HStack {
                    Text("Pending: ")
                        .bold()
                        .font(.system(size: 12))
                    + Text("\(appState.pendingUpdatesCount)")
                }
            }
        )
        .onAppear {
            if appState.preferences.mode == Constants.modes.munki {
                appState.pendingMunkiUpdatesManager.startInstallPercentageTask()
            }
            if appState.preferences.mode == Constants.modes.intune {
                appState.pendingIntuneUpdatesManager.startInstallPercentageTask()
            }
        }
        .onDisappear() {
            if appState.preferences.mode == Constants.modes.munki {
                appState.pendingMunkiUpdatesManager.stopInstallPercentageTask()
            }
            if appState.preferences.mode == Constants.modes.intune {
                appState.pendingIntuneUpdatesManager.stopInstallPercentageTask()
            }
        }
    }
}

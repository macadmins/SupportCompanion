import Foundation
import SwiftUI

struct CompactPatchProgressCard: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ScCardCompact(
            title: Constants.CardTitle.appPatchProgress,
            titleImageName: "app",
            imageSize: (13, 13),
            content: {
                AnyView(
                    ProgressView(
                        value: appState.installPercentage,
                        total: 100,
                        label: {
                            Text("\(String(format: "%.1f", appState.installPercentage))% Patched")
                            .font(.system(size: 12))}
                    )
                    .tint(appState.installPercentage < 90 ? (colorScheme == .light ? .orangeLight : .orange)
                        : appState.installPercentage < 60 ? (colorScheme == .light ? .redLight : .red)
                        : .ScGreen)
                )
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

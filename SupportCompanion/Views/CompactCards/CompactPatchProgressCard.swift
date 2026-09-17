import Foundation
import SwiftUI

struct CompactPatchProgressCard: View {
    @Environment(AppStateManager.self) var appState
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
                            Text("\(String(format: "%1d", Int(appState.installPercentage/100*100)))% Patched")
                                .font(.system(size: 12))
                        }
                    )
                    .tint(appState.installPercentage < 90 ? (colorScheme == .light ? .orangeLight : .orange)
                        : appState.installPercentage < 60 ? (colorScheme == .light ? .redLight : .red)
                        : .ScGreen)
                )
            }
        )
        .onAppear {
            appState.activeUpdatesManager?.startInstallPercentageTask()
        }
        .onDisappear() {
            appState.activeUpdatesManager?.stopInstallPercentageTask()
        }
    }
}

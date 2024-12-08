import Foundation
import SwiftUI

struct CompactStorageCard: View {
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.colorScheme) var colorScheme
            
    var body: some View {
        VStack(alignment: .leading){
            CustomCardCompact(
                title: AppStateManager.shared.storageInfoManager.storageInfo.name,
                titleImageName: "internaldrive.fill",
                buttonImageName: "info.circle",
                buttonAction: {},
                imageSize: (13, 13),
                content: {
                    VStack(alignment: .leading) {
                        AnyView(
                            ProgressView(
                                value: appState.storageInfoManager.storageInfo.usage,
                                total: 100,
                                label: {
                                    Text("\(String(format: "%.1f", appState.storageInfoManager.storageInfo.usage))% Used")
                                    .font(.system(size: 12))}
                            )
                            .tint(appState.storageInfoManager.storageInfo.usage < 50 ? Color.green
                                : appState.storageInfoManager.storageInfo.usage < 80 ? (colorScheme == .light ? .orangeLight : .orange)
                                : (colorScheme == .light ? .redLight : .red))
                        )
                    }
                }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear() {
            appState.storageInfoManager.refresh()
        }
    }
}
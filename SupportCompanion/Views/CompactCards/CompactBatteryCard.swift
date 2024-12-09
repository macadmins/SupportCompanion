import Foundation
import SwiftUI

struct CompactBatteryCard: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        ScCardCompact(
            title: "Battery",
            titleImageName: "battery.100percent",
            imageSize: (20, 20),
            content: {
                CardData(info: appState.batteryInfoManager.batteryInfo.toKeyValuePairsCompact(), fontSize: 12)
            }
        )
        .onAppear() {
            appState.batteryInfoManager.refresh()
        }
    }
}

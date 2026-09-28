import Foundation
import SwiftUI

struct CompactDeviceCard: View {
    @Environment(AppStateManager.self) var appState
    
    var body: some View {
        ScCardCompact(
            title: AppStateManager.shared.deviceInfoManager.deviceInfo?.hostName ?? "",
            titleImageName: "desktopcomputer",
            imageSize: (13, 13),
            content: {
                CardData(info: appState.deviceInfoManager.deviceInfo?.toKeyValuePairsCompact() ?? [], fontSize: 12)
            }
        )
    }
}

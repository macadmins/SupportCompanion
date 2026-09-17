//
//  CompactFleetInfoCard.swift
//  SupportCompanion
//

import SwiftUI

struct CompactFleetInfoCard: View {
    @Environment(AppStateManager.self) var appState

    var body: some View {
        ScCardCompact(
            title: Constants.CardTitle.fleetInfo,
            titleImageName: "server.rack",
            imageSize: (13, 13),
            content: {
                CardData(info: appState.fleetDeviceManager.infoRows, fontSize: 12)
            }
        )
        .task { await appState.fleetDeviceManager.refreshIfStale() }
    }
}

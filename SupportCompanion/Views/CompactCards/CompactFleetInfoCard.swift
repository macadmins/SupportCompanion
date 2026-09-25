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
                if appState.fleetDeviceManager.isSignedOut {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(Constants.Fleet.signedOutRecord)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ScSmallButton(Constants.Fleet.signIn) {
                            // Not present() directly: the sheet belongs to the main window, which may
                            // not be open from here. This opens it first, then signs in.
                            ActionHelpers.openManagementApp(appURL: "supportcompanion://fleetsignin")
                        }
                    }
                } else {
                    CardData(info: appState.fleetDeviceManager.infoRows, fontSize: 12)
                }
            }
        )
        .task { await appState.fleetDeviceManager.refreshIfStale() }
    }
}

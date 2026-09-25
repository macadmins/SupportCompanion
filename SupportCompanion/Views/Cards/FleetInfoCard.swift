//
//  FleetInfoCard.swift
//  SupportCompanion
//
//  This Mac's record in Fleet, shown under Battery like the Jamf card. Hide with HiddenCards `Fleet`.
//

import SwiftUI

struct FleetInfoCard: View {
    @Environment(AppStateManager.self) private var appState

    var body: some View {
        ScCard(title: Constants.CardTitle.fleetInfo, titleImageName: "server.rack", content: {
            VStack(alignment: .leading, spacing: 5) {
                // Fleet withholds the host record until sign-in, so the rows would all read Unknown.
                // One thing the user can act on beats five that say nothing.
                if appState.fleetDeviceManager.isSignedOut {
                    Text(Constants.Fleet.signedOutRecord)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ScSmallButton(Constants.Fleet.signIn) {
                        appState.fleetSSOController.present()
                    }
                    .padding(.top, 2)
                } else {
                    CardData(info: appState.fleetDeviceManager.infoRows)
                }
                Spacer()
            }
            .padding(.horizontal)
            .frame(maxHeight: .infinity, alignment: .top)
            .frame(minHeight: 110)
        })
        .fixedSize(horizontal: false, vertical: false)
        .task { await appState.fleetDeviceManager.refreshIfStale() }
    }
}

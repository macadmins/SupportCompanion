//
//  CompactFleetPoliciesCard.swift
//  SupportCompanion
//

import SwiftUI

struct CompactFleetPoliciesCard: View {
    @Environment(AppStateManager.self) var appState
    @Environment(\.colorScheme) var colorScheme

    private var manager: FleetDeviceManager { appState.fleetDeviceManager }

    var body: some View {
        ScCardCompact(
            title: Constants.CardTitle.fleetPolicies,
            titleImageName: "checkmark.shield.fill",
            imageSize: (13, 13),
            content: {
                summary
                    .font(.system(size: 12))
            }
        )
        .task { await manager.refreshIfStale() }
    }

    @ViewBuilder
    private var summary: some View {
        let failing = manager.failingPolicies
        let checked = manager.checkedPolicies
        VStack(alignment: .leading, spacing: 8) {
            if manager.host == nil {
                // Signed out, Fleet still gives a failing count through the ungated summary, so the
                // card can say what's actually wrong instead of asking the user to sign in blind
                if let failingCount = manager.failingChecksCount {
                    if failingCount > 0 {
                        Label(String(format: Constants.Fleet.signedOutFailing, failingCount),
                              systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(colorScheme == .light ? Color.orangeLight : .orange)
                    } else {
                        Label(Constants.Fleet.signedOutPassing, systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.ScGreen)
                    }
                } else {
                    Text(manager.isSignedOut ? Constants.Fleet.signInForChecks : Constants.FleetInfo.unknown)
                        .foregroundStyle(.secondary)
                }
            } else if checked.isEmpty {
                Text(Constants.Fleet.noPolicies)
                    .foregroundStyle(.secondary)
            } else if failing.isEmpty {
                Label(String(format: Constants.Fleet.policiesPassing, checked.count), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.ScGreen)
            } else {
                Label(String(format: Constants.Fleet.policiesFailing, failing.count, checked.count), systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(colorScheme == .light ? Color.orangeLight : .orange)
            }

            if manager.isSignedOut {
                ScSmallButton(Constants.Fleet.signIn) {
                    // Not present() directly: the sheet belongs to the main window, which may not be
                    // open from here. This opens it first, then signs in.
                    ActionHelpers.openManagementApp(appURL: "supportcompanion://fleetsignin")
                }
            }

            if manager.host != nil {
                HStack {
                    FleetRecheckButton(compact: true)
                    ScSmallButton(Constants.Fleet.complianceDetails) {
                        ActionHelpers.openManagementApp(appURL: "supportcompanion://compliance")
                    }
                }
            }
        }
    }
}

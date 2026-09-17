//
//  FleetComplianceBanner.swift
//  SupportCompanion
//
//  Shown at the top of Home in Fleet mode while any compliance check fails, so it's seen before the cards.
//

import SwiftUI

struct FleetComplianceBanner: View {
    /// Scrolls to the Device Compliance card.
    let showDetails: () -> Void

    @Environment(AppStateManager.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    private var manager: FleetDeviceManager { appState.fleetDeviceManager }

    var body: some View {
        let failing = manager.failingPolicies
        let color = failing.contains { $0.critical == true }
            ? (colorScheme == .light ? Color.redLight : .red)
            : (colorScheme == .light ? Color.orangeLight : .orange)

        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 3) {
                Text(String(format: Constants.Fleet.policiesFailing, failing.count, manager.checkedPolicies.count))
                    .font(.system(size: 16, weight: .semibold))
                Text(failing.map(\.name).joined(separator: " · "))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            ScButton(Constants.Fleet.complianceDetails, fontSize: 13) {
                showDetails()
            }
            FleetRecheckButton(fontSize: 13)
        }
        .padding()
        .isGlass()
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(color.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(radius: 4)
        .padding(5)
    }
}

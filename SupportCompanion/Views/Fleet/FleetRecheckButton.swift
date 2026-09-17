//
//  FleetRecheckButton.swift
//  SupportCompanion
//
//  Asks Fleet to re-read this Mac's details and re-run its compliance checks.
//

import SwiftUI

struct FleetRecheckButton: View {
    var fontSize: CGFloat?
    /// The small style used on the menu bar's compact cards.
    var compact = false
    @Environment(AppStateManager.self) private var appState

    var body: some View {
        let manager = appState.fleetDeviceManager
        let title = manager.isRefetching ? Constants.Actions.refetching : Constants.Actions.refetch
        // Failures are shown by the cards through refetchError
        if compact {
            ScSmallButton(title, disabled: manager.isRefetching) {
                try? await manager.refetch()
            }
            .help(manager.refetchError ?? Constants.Actions.refetchHelp)
        } else {
            ScButton(
                title,
                helpText: manager.refetchError ?? Constants.Actions.refetchHelp,
                disabled: manager.isRefetching,
                fontSize: fontSize
            ) {
                try? await manager.refetch()
            }
        }
    }
}

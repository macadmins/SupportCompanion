//
//  ActionsCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct ActionsCard: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager
    var onShowRebootModal: (Int, String, String) -> Void
    
    var body: some View {
        if viewModel.isCardVisible("Actions") {
            CustomCard(title: "\(Constants.CardTitle.actions)", titleImageName: "cursorarrow.click.2", content: {
                // Precompute the filtered and chunked buttons
                let visibleButtons = [
                    viewModel.isButtonVisible("Change Password") ? viewModel.createChangePasswordButton() : nil,
                    viewModel.isButtonVisible("Reboot") ? viewModel.createRebootButton(
                        onShowModal: { countdown, title, message in
                            onShowRebootModal(countdown, title, message)
                        }
                    ) : nil,
                    (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                        ? (viewModel.isButtonVisible("Open Management App") ? viewModel.createOpenManagementAppButton(type: .default) : nil)
                        : nil,
                    viewModel.isButtonVisible("Get Support") ? CustomButton(Constants.Actions.getSupport) { ActionHelpers.openSupportPage(url: appState.preferences.supportPageURL) } : nil,
                    viewModel.isButtonVisible("Gather Logs") ? viewModel.createGatherLogsButton() : nil,
                    viewModel.isButtonVisible("Software Updates") ? CustomButton(
                        Constants.Actions.softwareUpdate,
                        badgeNumber: appState.systemUpdateCache.updates.count,
                        helpText: appState.systemUpdateCache.updates.joined(separator: "\n"))
                    { ActionHelpers.openSystemUpdates() } : nil,
                    (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                        ? (viewModel.isButtonVisible("Restart Intune Agent") ? viewModel.createRestartIntuneAgentButton() : nil)
                        : nil
                ].compactMap { $0 } // Remove nil values
                
                let buttonRows = Array(visibleButtons.chunked(into: 2)) // Chunk into rows of 2
                
                // Layout
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(buttonRows.indices, id: \.self) { rowIndex in
                        HStack(spacing: 10) {
                            ForEach(buttonRows[rowIndex], id: \.self) { button in
                                button
                            }
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .center)
            })
        }
    }
}

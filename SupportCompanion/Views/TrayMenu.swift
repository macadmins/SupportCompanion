//
//  TrayMenu.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-07.
//

import Foundation
import SwiftUI

struct TrayMenuView: View {
    @EnvironmentObject var appState: AppStateManager
    @ObservedObject var viewModel: CardGridViewModel

    var body: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        VStack(spacing: 20) { // Increase spacing for more breathing room
            // Title at the top
            Spacer()
            Text(appState.preferences.brandName)
                .font(.headline)
            //Spacer()
            
            // Main content (Grid and Buttons)
            VStack(spacing: 20) { // Increased spacing between grid and buttons
                LazyVGrid(columns: columns, alignment: .leading) { // Add spacing between cards
                    if !appState.preferences.hiddenCards.contains("Battery") {
                        CompactBatteryCard()
                    }
                    if !appState.preferences.hiddenCards.contains("DeviceInformation") {
                        CompactDeviceCard()
                    }
                    if !appState.preferences.hiddenCards.contains("Storage") {
                        CompactStorageCard()
                    }
                    if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
                        if !appState.preferences.hiddenCards.contains("ApplicationInstallProgress") {
                            CompactPatchProgressCard()
                        }
                    }
                }
                
                Divider()
                
                ButtonSection(viewModel: viewModel, appState: appState)
                    //.frame(maxWidth: .infinity)
                
                Divider()
                
                if appState.preferences.actions.count > 0 {
                    let actionCols = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    
                    LazyVGrid(columns: actionCols, alignment: .leading, spacing: 20) {
                        ForEach(appState.preferences.actions.prefix(6), id: \.self) { action in
                            ScCardCompactButton(
                                title: action.name,
                                titleImageName: action.icon,
                                buttonAction: action,
                                imageSize: (13, 13),
                                useMultiColor: false
                            )
                        }
                    }
                }
            }
            .padding(.horizontal)
            
            // Footer at the bottom
            Spacer()
            Button(Constants.TrayMenu.quitApp) {
                NSApplication.shared.terminate(nil)
            }
            Spacer()
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: 480, maxWidth: .infinity, idealHeight: 800, maxHeight: .infinity)
    }

    /// Calculates the ideal height for the VStack based on the number of elements.
    private func calculateIdealHeight() -> CGFloat {
        let titleHeight: CGFloat = 60 // Title + padding
        let footerHeight: CGFloat = 50 // Footer button height
        let gridRows = (visibleCardsCount() + 1) / 2 // Number of rows in the grid (2 columns per row)
        let gridHeight: CGFloat = CGFloat(gridRows) * 100 // Each row takes ~100px
        let buttonRows = ceil(Double(visibleButtonsCount()) / 3.0) // 3 buttons per row
        let buttonHeight: CGFloat = CGFloat(buttonRows) * 60 // Each button row takes ~60px
        let actionsHeight: CGFloat = 100 // Configured actions height

        return titleHeight + footerHeight + gridHeight + buttonHeight + actionsHeight + 40 // Extra padding
    }

    /// Counts visible cards in the grid
    private func visibleCardsCount() -> Int {
        var count = 0
        if !appState.preferences.hiddenCards.contains("Battery") { count += 1 }
        if !appState.preferences.hiddenCards.contains("DeviceInformation") { count += 1 }
        if !appState.preferences.hiddenCards.contains("Storage") { count += 1 }
        if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
            if !appState.preferences.hiddenCards.contains("ApplicationInstallProgress") {
                count += 1
            }
        }
        return count
    }

    /// Counts visible buttons in the navigation section
    private func visibleButtonsCount() -> Int {
        let buttons = [
            true, // Home is always visible
            AppStateManager.shared.preferences.menuShowIdentity,
            AppStateManager.shared.preferences.menuShowApps,
            AppStateManager.shared.preferences.menuShowSelfService,
            viewModel.isButtonVisible("ChangePassword"),
            appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune,
            viewModel.isButtonVisible("GetSupport"),
            viewModel.isButtonVisible("GatherLogs"),
            viewModel.isButtonVisible("SoftwareUpdates"),
            viewModel.isButtonVisible("RestartIntuneAgent")
        ]
        return buttons.filter { $0 }.count
    }
}

struct ButtonSection: View {
    @ObservedObject var viewModel: CardGridViewModel
    let url = "supportcompanion://"
    let appState: AppStateManager
    
    var body: some View {
        let visibleButtons = [
            ScButton(Constants.TrayMenu.openApp, fontSize: 12, action: {
                DispatchQueue.main.async {
                        appState.showWindowCallback?()
                }
            }),
            viewModel.isButtonVisible("ChangePassword") ? viewModel.createChangePasswordButton(fontSize: 12) : nil,
            (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                ? (viewModel.isButtonVisible("OpenManagementApp") ? viewModel.createOpenManagementAppButton(type: .default, fontSize: 12) : nil)
                : nil,
            viewModel.isButtonVisible("GetSupport") ? ScButton(Constants.Actions.getSupport, fontSize: 12) { ActionHelpers.openSupportPage(url: appState.preferences.supportPageURL) } : nil,
            viewModel.isButtonVisible("GatherLogs") ? viewModel.createGatherLogsButton(fontSize: 12) : nil,
            viewModel.isButtonVisible("SoftwareUpdates") ? ScButton(
                Constants.Actions.softwareUpdate,
                badgeNumber: appState.systemUpdateCache.updates.count,
                helpText: appState.systemUpdateCache.updates.joined(separator: "\n"),
                fontSize: 12)
            { ActionHelpers.openSystemUpdates() } : nil,
            (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                ? (viewModel.isButtonVisible("RestartIntuneAgent") ? viewModel.createRestartIntuneAgentButton(fontSize: 12) : nil)
                : nil
        ].compactMap { $0 } // Remove nil values

        let buttonRows = Array(visibleButtons.chunked(into: 3))
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
        .frame(maxWidth: .infinity)
    }
}

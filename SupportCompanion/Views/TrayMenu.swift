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
    @Environment(\.colorScheme) var colorScheme
    @State private var brandLogo: Image? = nil
    @State private var showLogo: Bool = false

    var body: some View {
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]

        VStack(spacing: 20) { // Increase spacing for more breathing room
            // Title at the top
            Spacer()
            if showLogo, let logo = brandLogo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 150)
                        .fixedSize(horizontal: false, vertical: true)
                }

            // Title Section
            if !appState.preferences.brandName.isEmpty {
                Text(appState.preferences.brandName)
                    .font(.headline)
            }
            //Spacer()
            
            // Main content (Grid and Buttons)
            VStack(spacing: 20) { // Increased spacing between grid and buttons
                LazyVGrid(columns: columns, alignment: .leading) { // Add spacing between cards
                    if !appState.preferences.hiddenCards.contains(Constants.Cards.battery) {
                        CompactBatteryCard()
                    }
                    if !appState.preferences.hiddenCards.contains(Constants.Cards.deviceInfo) {
                        CompactDeviceCard()
                    }
                    if !appState.preferences.hiddenCards.contains(Constants.Cards.storage) {
                        CompactStorageCard()
                    }
                    if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
                        if !appState.preferences.hiddenCards.contains(Constants.Cards.appPatchProgress) {
                            CompactPatchProgressCard()
                        }
                    }
                    if appState.preferences.enableElevation && appState.preferences.showElevateTrayCard {
                        CompactElevationCard()
                    }
                }
                
                Divider()
                
                ButtonSection(viewModel: viewModel, appState: appState)
                
                Divider()
                
                if appState.preferences.actions.count > 0 {
                    let actionCols = [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ]
                    
                    LazyVGrid(columns: actionCols, alignment: .leading, spacing: 10) {
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
            //Spacer()
            Button(Constants.TrayMenu.quitApp) {
                NSApplication.shared.terminate(nil)
            }
            .padding(.top, 10)
            Spacer()
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: 480, maxWidth: .infinity, idealHeight: 800, maxHeight: .infinity)
        .onAppear() {
            loadLogoForCurrentColorScheme()
        }
        .onChange(of: colorScheme) { _, _ in
            loadLogoForCurrentColorScheme()
        }
        .background(colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.2))
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
        if !appState.preferences.hiddenCards.contains(Constants.Cards.battery) { count += 1 }
        if !appState.preferences.hiddenCards.contains(Constants.Cards.deviceInfo) { count += 1 }
        if !appState.preferences.hiddenCards.contains(Constants.Cards.storage) { count += 1 }
        if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
            if !appState.preferences.hiddenCards.contains(Constants.Cards.appPatchProgress) {
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
            viewModel.isButtonVisible(Constants.Actions.HideStrings.changePassword),
            appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune,
            viewModel.isButtonVisible(Constants.Actions.HideStrings.getSupport),
            viewModel.isButtonVisible(Constants.Actions.HideStrings.gatherLogs),
            viewModel.isButtonVisible(Constants.Actions.HideStrings.softwareUpdate),
            viewModel.isButtonVisible(Constants.Actions.HideStrings.restartIntuneAgent)
        ]
        return buttons.filter { $0 }.count
    }

    private func loadLogoForCurrentColorScheme() {
        if appState.preferences.showLogoInTrayMenu == false {
            showLogo = false
            return
        }
        let base64Logo = colorScheme == .dark ? appState.preferences.brandLogo : appState.preferences.brandLogoLight.isEmpty ? appState.preferences.brandLogo : appState.preferences.brandLogoLight
        showLogo = loadLogo(base64Logo: base64Logo)
        if showLogo {
            brandLogo = base64ToImage(base64Logo)
        }
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
            viewModel.isButtonVisible(Constants.Actions.HideStrings.changePassword) ? viewModel.createChangePasswordButton(fontSize: 12) : nil,
            viewModel.isButtonVisible(Constants.Actions.HideStrings.getSupport) ? ScButton(Constants.Actions.getSupport, fontSize: 12) { ActionHelpers.openSupportPage(url: appState.preferences.supportPageURL) } : nil,
            (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                ? (viewModel.isButtonVisible(Constants.Actions.HideStrings.openManagementApp) ? viewModel.createOpenManagementAppButton(type: .default, fontSize: 12) : nil)
                : nil,
            viewModel.isButtonVisible(Constants.Actions.HideStrings.gatherLogs) ? viewModel.createGatherLogsButton(fontSize: 12) : nil,
            viewModel.isButtonVisible(Constants.Actions.HideStrings.softwareUpdate) ? ScButton(
                Constants.Actions.softwareUpdate,
                badgeNumber: appState.systemUpdateCache.updates.count,
                helpText: appState.systemUpdateCache.updates.joined(separator: "\n"),
                fontSize: 12)
            { ActionHelpers.openSystemUpdates() } : nil,
            (appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune)
                ? (viewModel.isButtonVisible(Constants.Actions.HideStrings.restartIntuneAgent) ? viewModel.createRestartIntuneAgentButton(fontSize: 12) : nil)
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 5)
    }
}
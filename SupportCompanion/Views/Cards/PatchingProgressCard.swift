//
//  PatchingProgressCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct PatchingProgressCard: View {
    var viewModel: CardGridViewModel
    @Environment(AppStateManager.self) var appState

    var body: some View {
        if viewModel.isCardVisible(Constants.Cards.appPatchProgress) {
            VStack {
                ScCard(title: "\(Constants.CardTitle.appPatchProgress)", titleImageName: "app.badge.checkmark", content: {
                    ZStack {
                        CircularProgressWithWave(
                            progress: appState.installPercentage / 100,
                            size: 200,
                            waveHeight: (appState.installPercentage == 0.0 || appState.installPercentage == 100.0) ? 0 : 5,
                            tint: NSColor(hex: appState.preferences.branding.accentColor ?? "") ?? .controlAccentColor
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                })
            }
            .onAppear {
                appState.activeUpdatesManager?.startInstallPercentageTask()
            }
            .onDisappear {
                appState.activeUpdatesManager?.stopInstallPercentageTask()
            }
            .onChange(of: appState.windowIsVisible) { oldValue, newValue in
                if !newValue {
                    appState.activeUpdatesManager?.stopInstallPercentageTask()
                }
            }
        }
    }
}

//
//  PatchingProgressCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct PatchingProgressCard: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        if viewModel.isCardVisible("ApplicationInstallProgress") {
            VStack {
                CustomCard(title: "\(Constants.CardTitle.appPatchProgress)", titleImageName: "app.badge.checkmark", content: {
                    ZStack {
                        CircularProgressWithWave(
                            progress: appState.installPercentage / 100,
                            size: 200,
                            waveHeight: (appState.installPercentage == 0.0 || appState.installPercentage == 100.0) ? 0 : 5
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                })
            }
            .onAppear {
                if appState.preferences.mode == Constants.modes.munki {
                    appState.pendingMunkiUpdatesManager.startInstallPercentageTask()
                }
                if appState.preferences.mode == Constants.modes.intune {
                    appState.pendingIntuneUpdatesManager.startInstallPercentageTask()
                }
            }
            .onDisappear {
                if appState.preferences.mode == Constants.modes.munki {
                    appState.pendingMunkiUpdatesManager.stopInstallPercentageTask()
                }
                if appState.preferences.mode == Constants.modes.intune {
                    appState.pendingIntuneUpdatesManager.stopInstallPercentageTask()
                }
            }
            .onChange(of: appState.windowIsVisible) { oldValue, newValue in
                if !newValue {
                    if appState.preferences.mode == Constants.modes.munki {
                        appState.pendingMunkiUpdatesManager.stopInstallPercentageTask()
                    }
                    if appState.preferences.mode == Constants.modes.intune {
                        appState.pendingIntuneUpdatesManager.stopInstallPercentageTask()
                    }
                }
            }
        }
    }
}

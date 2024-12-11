//
//  GridView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation
import SwiftUI
import AlertToast

struct CardGrid: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager
    @State private var showRebootModal = false
    @State private var modalCountdown = Constants.RebootModal.countdown
    @State private var modalTitle = Constants.RebootModal.title
    @State private var modalMessage = ""

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), ]
        ZStack{
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading
                ) {
                    // Device Information Card
                    DeviceInformationCard(viewModel: viewModel)
                    
                    // Evergreen and Battery cards
                    BatteryEvergreenStack(viewModel: viewModel)
                    
                    // Actions Card
                    ActionsCard(
                        viewModel: viewModel,
                        onShowRebootModal: { countdown, title, message in
                            modalCountdown = Constants.RebootModal.countdown
                            modalTitle = title
                            modalMessage = message
                            showRebootModal = true
                        }
                    )
                    
                    // Storage and Device Management cards
                    StorageDeviceManagementStack(viewModel: viewModel)
                    
                    // Patching progress card
                    if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
                        PatchingProgressCard(viewModel: viewModel)
                        PendingUpdatesCard(viewModel: viewModel)
                    }
                    
                    if appState.JsonCards.count > 0 {
                        ForEach(appState.JsonCards) { card in
                            JsonCardView(card: card)
                        }
                    }
                }
                .padding(20)
                .onAppear{
                    if !appState.preferences.customCardPath.isEmpty {
                        let cardManager = JsonCardManager(appState: appState)
                        cardManager.loadFromFile(appState.preferences.customCardPath)
                    }
                }
            }
            CountdownModal(
                isPresented: $showRebootModal,
                countdown: modalCountdown,
                title: modalTitle,
                message: modalMessage
            ) {
                modalCountdown = Constants.RebootModal.countdown // Reset countdown in CardGrid
                showRebootModal = false                         // Close the modal
            }
        }
        .toast(isPresenting: Binding(
            get: { viewModel.toastConfig?.isShowing ?? false },
            set: { value in viewModel.toastConfig?.isShowing = value }
        ), duration: 5, tapToDismiss: true) {
            if let toastConfig = viewModel.toastConfig {
                AlertToast(
                    type: toastConfig.type,
                    title: toastConfig.title,
                    subTitle: toastConfig.subTitle
                )
            } else {
                AlertToast(type: .regular, title: "No message")
            }
        }
    }
}

struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        .environmentObject(AppStateManager.shared)
        .frame(width: 1400, height: 900)
    }
}

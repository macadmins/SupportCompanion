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
        let columns = [
            GridItem(.adaptive(minimum: 300), alignment: .top)
        ]
        ZStack{
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading
                ) {
                    // Device Information Card
                    DeviceInformationCard(viewModel: viewModel)
                    
                    // Patching progress card
                    if appState.preferences.mode == Constants.modes.munki || appState.preferences.mode == Constants.modes.intune {
                        PatchingProgressCard(viewModel: viewModel)
                        PendingUpdatesCard(viewModel: viewModel)
                    }
                    
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
                    
                    ForEach(getVisibleStacks(viewModel: viewModel), id: \.id) { stack in
                        stack.view
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                //.padding(.top, 20)

                LazyVGrid(columns: columns) {
                    if appState.JsonCards.count > 0 && appState.preferences.customCardsMenuLabel.isEmpty {
                        ForEach(appState.JsonCards) { card in
                            JsonCardView(card: card)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .onAppear{
                    if appState.preferences.customCardPath.isEmpty && appState.preferences.customCardsMenuLabel.isEmpty {
                        appState.refreshJsonCards()
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
        .onAppear {
            if !appState.preferences.hiddenCards.contains(Constants.CardTitle.evergreen) {
                appState.evergreenInfoManager.refresh()
            }
            if !appState.preferences.hiddenCards.contains(Constants.CardTitle.battery) {
                appState.batteryInfoManager.startMonitoring()
            }
        }
        .onDisappear {
            if !appState.preferences.hiddenCards.contains(Constants.CardTitle.battery) {
                appState.batteryInfoManager.stopMonitoring()
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

func getVisibleStacks(viewModel: CardGridViewModel) -> [(id: String, view: AnyView)] {
    var visibleStacks: [(id: String, view: AnyView)] = []
    
    // Conditional logic to arrange Battery and Storage/Device stacks
    if viewModel.isCardVisible(Constants.Cards.storage) && viewModel.isCardVisible(Constants.Cards.deviceManagement) {
        // Both Storage and Device Management are visible: Split columns
        visibleStacks.append(
            (id: "StorageDeviceManagement",
             view: AnyView(
                StorageDeviceManagementStack(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(1)
            ))
        )
        
        visibleStacks.append(
            (id: "BatteryEvergreen",
             view: AnyView(
                BatteryEvergreenStack(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(1)
            ))
        )
    } else {
        // Otherwise, span the grid
        visibleStacks.append(
            (id: "BatteryEvergreen",
             view: AnyView(
                BatteryEvergreenStack(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(2)
            ))
        )
        
        visibleStacks.append(
            (id: "StorageDeviceManagement",
             view: AnyView(
                StorageDeviceManagementStack(viewModel: viewModel)
                    .frame(maxWidth: .infinity)
                    .gridCellColumns(2)
            ))
        )
    }

    return visibleStacks
}

struct CardGridView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        .environmentObject(AppStateManager.shared)
        .frame(width: 1500, height: 100)
    }
}

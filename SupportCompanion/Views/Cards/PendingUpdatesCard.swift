//
//  PendingMunkiUpdates.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct PendingUpdatesCard: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        if viewModel.isCardVisible(Constants.Cards.pendingAppUpdates) {
            VStack {
                ScCard(
                    title: "\(Constants.CardTitle.pendingUpdates)",
                    titleImageName: "clock.fill",
                    content: {
                        VStack {
                            headerView
                            pendingUpdatesList
                            viewModel.createOpenManagementAppButton(type: .update)
                        }
                    }
                )
            }
            .onAppear(perform: startFetching)
            .onDisappear(perform: stopFetching)
            .onChange(of: appState.windowIsVisible) { oldValue, newValue in
                handleVisibilityChange(newValue)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(Constants.TabelHeaders.name)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Constants.TabelHeaders.version)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .trailing)
            if appState.preferences.mode == Constants.modes.intune {
                Text("")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal)
        .background(Color.clear)
    }
    
    @ViewBuilder
    private var pendingUpdatesList: some View {
        if appState.preferences.mode == Constants.modes.munki {
            updateList(items: appState.pendingMunkiUpdates)
        } else if appState.preferences.mode == Constants.modes.intune {
            updateList(items: appState.pendingIntuneUpdates)
        }
    }
    
    private func updateList<T: Identifiable>(items: [T]) -> some View where T: PendingUpdate {
        List {
            if items.isEmpty {
                Text("No pending updates")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(items) { update in
                    HStack {
                        Text(update.name)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(update.version)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.gray)
                        if let intuneUpdate = update as? PendingIntuneUpdate, intuneUpdate.showInfoIcon {
                            Image(systemName: "info.circle")
                                .help(intuneUpdate.pendingReason)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .listRowSeparator(.hidden)
                    Divider()
                }
            }
        }
        .padding(.horizontal, 8)
        .scrollContentBackground(.hidden)
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
    
    private func startFetching() {
        DispatchQueue.main.async {
            if appState.preferences.mode == Constants.modes.munki {
                appState.pendingMunkiUpdatesManager.startFetchingList()
            } else if appState.preferences.mode == Constants.modes.intune {
                appState.pendingIntuneUpdatesManager.startFetchingList()
            }
        }
    }

    private func stopFetching() {
        DispatchQueue.main.async {
            if appState.preferences.mode == Constants.modes.munki {
                appState.pendingMunkiUpdatesManager.stopFetchingList()
            } else if appState.preferences.mode == Constants.modes.intune {
                appState.pendingIntuneUpdatesManager.stopFetchingList()
            }
        }
    }
    
    private func handleVisibilityChange(_ newValue: Bool) {
        if !newValue {
            stopFetching()
        }
    }
}

struct PendingMunkiUpdatesCard_Previews: PreviewProvider {
    static var previews: some View {
        PendingUpdatesCard(viewModel: CardGridViewModel(appState: AppStateManager()))
            .previewLayout(.sizeThatFits)
    }
}

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
    @Environment(\.colorScheme) var colorScheme

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
                                .padding(.top, 10)
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
		} else if appState.preferences.mode == Constants.modes.jamf {
			updateList(items: appState.pendingJamfUpdates)
		}
    }
    
    private func updateList<T: Identifiable>(items: [T]) -> some View where T: PendingUpdate {
        List {
            if items.isEmpty {
                Text("No pending updates")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
				ForEach(items) { update in
					HStack(spacing: 8) {
						// Keep this leading text flexible
						Text(update.name)
							.lineLimit(1)
							.truncationMode(.tail)

						Spacer()

						// Keep this trailing text compact; no infinite frames
						Text(update.version)
							.foregroundColor(colorScheme == .dark ? .gray : .grayLight)
							.lineLimit(1)
					}
					.padding(.vertical, 6)
					.listRowSeparator(.hidden)
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
            } else if appState.preferences.mode == Constants.modes.jamf {
                appState.pendingJamfUpdatesManager.startFetchingList()
            }
        }
    }

    private func stopFetching() {
        DispatchQueue.main.async {
            if appState.preferences.mode == Constants.modes.munki {
                appState.pendingMunkiUpdatesManager.stopFetchingList()
            } else if appState.preferences.mode == Constants.modes.intune {
                appState.pendingIntuneUpdatesManager.stopFetchingList()
            } else if appState.preferences.mode == Constants.modes.jamf {
                appState.pendingJamfUpdatesManager.stopFetchingList()
            }
        }
    }
    
    private func handleVisibilityChange(_ newValue: Bool) {
        if !newValue {
            stopFetching()
        }
    }
}

//
//  PendingMunkiUpdates.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct PendingUpdatesCard: View {
    var viewModel: CardGridViewModel
    @Environment(AppStateManager.self) var appState
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
            Text(Constants.TableHeaders.name)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Constants.TableHeaders.version)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .trailing)
            if let detailTitle = appState.activeUpdatesManager?.pendingUpdatesDetailColumnTitle {
                Text(detailTitle)
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal)
        .background(Color.clear)
    }
    
    private var pendingUpdatesList: some View {
        updateList(items: appState.activeUpdatesManager?.pendingUpdates ?? [])
    }
    
    /// Concrete row type: ForEach with a key path over `any PendingUpdate` crashes the Swift compiler.
    private struct Row: Identifiable {
        let id: UUID
        let name: String
        let version: String
        let dueBy: String?
    }

    private func updateList(items: [any PendingUpdate]) -> some View {
        let rows = items.map { Row(id: $0.id, name: $0.name, version: $0.version, dueBy: $0.dueBy) }
        return List {
            if rows.isEmpty {
                Text("No pending updates")
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ForEach(rows) { update in
                    HStack(spacing: 8) {
                        // Keep this leading text flexible
                        Text(update.name)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .truncationMode(.tail)

                        Spacer()

                        // Keep this trailing text compact; no infinite frames
                        Text(update.version)
                            .foregroundColor(colorScheme == .dark ? .gray : .grayLight)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .trailing)

                        if let dueBy = update.dueBy {
                            Text(dueBy)
                                .foregroundColor(colorScheme == .dark ? .gray : .grayLight)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
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
        appState.activeUpdatesManager?.startFetchingList()
    }

    private func stopFetching() {
        appState.activeUpdatesManager?.stopFetchingList()
    }
    
    private func handleVisibilityChange(_ newValue: Bool) {
        if !newValue {
            stopFetching()
        }
    }
}

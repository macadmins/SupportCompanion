//
//  Applications.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-22.
//

import Foundation
import SwiftUI

struct Applications: View {
    @Environment(AppStateManager.self) var appState
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var task: Task<Void, Never>?

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            if isLoading {
                loading
            } else if appState.installedApplications.isEmpty {
                empty
            } else {
                catalog
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            isLoading = true
            let appInfoManager = ApplicationsInfoManager(appState: appState) // Local instance

            task = Task {
                defer { isLoading = false } // Ensure `isLoading` is reset
                await appInfoManager.fetchAppsBasedOnMode()
            }

            appState.applicationsInfoManager.startMonitoring()
        }
        .onDisappear {
            task?.cancel() // Cancel any running Task
            appState.applicationsInfoManager.stopMonitoring()
        }
    }

    // MARK: - States

    private var loading: some View {
        VStack {
            ProgressView("Loading applications...")
                .progressViewStyle(CircularProgressViewStyle())
                .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
    }

    private var empty: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundColor(.primary)
            Text("No installed applications found")
                .font(.title)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .ignoresSafeArea()
    }

    // MARK: - Catalog

    private var catalog: some View {
        VStack(alignment: .leading, spacing: 12) {
            searchRow

            let mode = appState.preferences.mode
            if mode != Constants.Modes.systemProfiler {
                Text("This list shows applications installed by \(mode).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if matching.isEmpty {
                Text(Constants.Apps.noMatches)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // Apps with an update come first: it is the only part of this page somebody has
                        // to act on, and it used to be findable only by scrolling for the one card with
                        // an Update button on it.
                        if !updatable.isEmpty {
                            section(Constants.Apps.updatesAvailable, updatable)
                        }

                        if !upToDate.isEmpty {
                            section(Constants.Apps.installed, upToDate)
                        }
                    }
                    .padding(.bottom, 5)
                }
            }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(Constants.Apps.searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(Constants.Apps.clearSearch)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: 320)
        .isGlass()
        .cornerRadius(8)
    }

    private func section(_ name: String, _ apps: [InstalledApp]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(name).font(.headline)
                Text("\(apps.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, alignment: .leading) {
                ForEach(apps) { card in
                    AppCard(card: card)
                        .fixedSize(horizontal: false, vertical: false) // Allow vertical expansion
                }
            }
        }
    }

    // MARK: - Grouping

    private var matching: [InstalledApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return appState.installedApplications }

        return appState.installedApplications.filter {
            $0.name.localizedCaseInsensitiveContains(query)
        }
    }

    /// Names of installed apps an update is waiting for.
    ///
    /// Taken from the active manager rather than by asking which mode is configured, so a mode that
    /// starts reporting `installedAppName` gets the section without this view changing.
    private var appNamesWithUpdates: Set<String> {
        Set(
            (appState.activeUpdatesManager?.pendingUpdates ?? [])
                .compactMap(\.installedAppName)
        )
    }

    private var updatable: [InstalledApp] {
        let waiting = appNamesWithUpdates
        return matching.filter { waiting.contains($0.name) }
    }

    private var upToDate: [InstalledApp] {
        let waiting = appNamesWithUpdates
        return matching.filter { !waiting.contains($0.name) }
    }
}

//
//  Applications.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-22.
//

import Foundation
import SwiftUI

struct Applications: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var isHovered = false
    @State private var isLoading = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        ZStack {
            if isLoading {
                // Centered ProgressView
                VStack {
                    ProgressView("Loading applications...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Full screen
                .background(Color.black.opacity(0.1)) // Optional dimming effect
                .ignoresSafeArea() // Ensure it covers the entire screen
            } else {
                // Main content
                CustomCard(
                    title: "\(Constants.CardTitle.installedApps)",
                    titleImageName: "app.fill",
                    content: {
                        ScrollView {
                            VStack {
                                // Header
                                applicationHeader()

                                // Application list
                                applicationList()
                            }
                            .padding(.vertical) // Add vertical padding for the scroll content
                        }
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            }
        }
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

    // Extract header into its own ViewBuilder
    @ViewBuilder
    private func applicationHeader() -> some View {
        HStack {
            Text(Constants.TabelHeaders.name)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(Constants.TabelHeaders.version)
                .font(.subheadline)
                .bold()
                .frame(maxWidth: .infinity, alignment: .trailing)
            if appState.preferences.mode == Constants.modes.munki {
                Text(Constants.TabelHeaders.action)
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if appState.preferences.mode == Constants.modes.systemProfiler {
                Text("Arch")
                    .font(.subheadline)
                    .bold()
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 5)
        .padding(.horizontal)
        .background(Color.clear)
    }

    // Extract list into its own ViewBuilder
    @ViewBuilder
    private func applicationList() -> some View {
        LazyVStack {
            if appState.installedApplications.isEmpty {
                Text("No installed applications found")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
            } else {
                ForEach(appState.installedApplications) { app in
                    applicationRow(for: app)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // Extract row into its own function
    @ViewBuilder
    private func applicationRow(for app: InstalledApp) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(app.name)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(app.version)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .foregroundColor(.gray)
                if app.isSelfServe {
                    CustomButton(Constants.General.manage, action: {
                        Task {
                            if !app.action.isEmpty {
                                _ = try await ExecutionService.executeShellCommand(app.action)
                            }
                        }
                    })
                    .frame(maxWidth: .infinity, alignment: .trailing)
                } else if appState.preferences.mode == Constants.modes.systemProfiler {
                    Text(app.arch)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .foregroundColor(.gray)
                } else {
                    if appState.preferences.mode != Constants.modes.intune{
                        Text("")
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .foregroundColor(.gray)
                    }
                }
            }
            .hoverEffect {
                Color.gray.opacity(0.2) // Background color on hover
            }
            Divider() // Divider for rows
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
    }
}


struct HoverEffect<Background: View>: ViewModifier {
    let background: () -> Background
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                isHovered ? background() as! Color : Color.clear
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverEffect<Background: View>(@ViewBuilder background: @escaping () -> Background) -> some View {
        self.modifier(HoverEffect(background: background))
    }
}


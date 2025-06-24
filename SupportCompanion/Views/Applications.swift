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
    @State private var isLoading = false
    @State private var task: Task<Void, Never>?
    
    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ZStack {
            if isLoading {
                // Centered ProgressView
                VStack {
                    ProgressView("Loading applications...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity) // Full screen
                .background(Color.clear)
                .ignoresSafeArea() // Ensure it covers the entire screen
            } else {
                if appState.installedApplications.isEmpty {
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
                    .frame(maxWidth: .infinity, maxHeight: .infinity) // Full screen
                    .background(Color.clear)
                    .ignoresSafeArea() // Ensure it covers the entire screen
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: columns,
                            alignment: .leading
                        ) {
                            ForEach(appState.installedApplications) { card in
                                AppCard(card: card)
                                    .fixedSize(horizontal: false, vertical: false) // Allow vertical expansion
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
}

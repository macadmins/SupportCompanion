//
//  SelfService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-22.
//

import Foundation
import SwiftUI

struct SelfService: View {
    @EnvironmentObject var appState: AppStateManager

    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        ZStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading) {
                    ForEach(appState.preferences.actions) { action in
                        SelfServiceCard(action: action)
                    }
                }
                .padding(.horizontal, 20)
                .id(appState.preferences.actions)
            }
            .onAppear {
                appState.userInfoManager.refresh()
                Task {
                    await appState.ssoInfoManager.refresh()
                }
            }
        }
    }

    struct SelfServiceCard: View {
        let action: Action

        var body: some View {
            ScCard(
                title: action.name,
                titleImageName: action.icon,
                useMultiColor: false,
                content: {
                    VStack(alignment: .leading, spacing: 5) {
                        if let description = action.description, !description.isEmpty {
                            Text(description)
                                .font(.system(size: 14))
                                .padding(.bottom, 5)
                        }
                        
                        Spacer() // Push the button to the bottom
                        
                            ScButton(action.buttonLabel ?? "Run", maxWidth: 150) {
                                do {
                                    _ = try await ExecutionService.executeShellCommand(action.command, isPrivileged: action.isPrivileged)
                                } catch {
                                    Logger.shared.logError("Self Service action '\(action.command)' failed: \(error)")
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                    }
                    .frame(maxHeight: .infinity) // Ensure the VStack takes full available height
                    .padding(.horizontal)
                }
            )
        }
    }
}

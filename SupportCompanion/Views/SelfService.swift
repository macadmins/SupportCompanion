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
                //.padding(.top, 20)
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
        //@State private var isRunning: Bool = false

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
                        
                        /*if isRunning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .center)
                        } else {*/
                            ScButton(action.buttonLabel ?? "Run", maxWidth: 150) {
                                //isRunning = true
                                //defer { isRunning = false }
                                _ = try? await ExecutionService.executeShellCommand(action.command, isPrivileged: action.isPrivileged)
                            }
                            .frame(maxWidth: .infinity, alignment: .bottom)
                        //}
                    }
                    .frame(maxHeight: .infinity) // Ensure the VStack takes full available height
                    .padding(.horizontal)
                }
            )
        }
    }
}

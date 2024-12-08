import Foundation
import SwiftUI

struct QuickActions: View {
    let appStateManager: AppStateManager
    @State private var selectedOption: Action = AppStateManager.shared.preferences.actions.first!
    @State private var actionStatus: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            Text("Quick Actions")
                .font(.headline)
                .padding(.bottom, 8)

            // Action Picker and Run Button inside a Card
            HStack {
                Picker("Select an action", selection: $selectedOption) {
                    ForEach(appStateManager.preferences.actions, id: \.self) { action in
                        HStack {
                            Image(systemName: action.icon ?? "wrench.fill") // Replace with relevant SF Symbols
                            Text(action.name)
                        }
                        .tag(action)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(maxWidth: .infinity)
                Button(action: {
                    runSelectedAction()
                }) {
                    HStack {
                        Image(systemName: actionStatus == nil ? "play.circle.fill" : "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(actionStatus == nil ? "Run" : "Done")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundColor(.white)
                    .background(Color(NSColor(hex: AppStateManager.shared.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
                .buttonStyle(PlainButtonStyle())
                .animation(.easeInOut, value: actionStatus)
            }
        }
        .padding(.horizontal)
    }

    private func runAction(action: Action) {
        Task {
            _ = try await ExecutionService.executeShellCommand(action.command, isPrivileged: action.isPrivileged)
        }
    }

    private func runSelectedAction() {
        Task {
            actionStatus = nil
            await runAction(action: selectedOption)
            actionStatus = "Completed"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                actionStatus = nil // Reset the button state
            }
        }
    }
}
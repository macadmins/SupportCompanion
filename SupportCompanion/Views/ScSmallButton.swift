//
//  ScSmallButton.swift
//  SupportCompanion
//
//  The small button used on the menu bar's compact cards.
//

import SwiftUI

struct ScSmallButton: View {
    let title: String
    var disabled = false
    let action: () async -> Void

    @Environment(AppStateManager.self) private var appState
    @State private var isRunning = false

    init(_ title: String, disabled: Bool = false, action: @escaping () async -> Void) {
        self.title = title
        self.disabled = disabled
        self.action = action
    }

    var body: some View {
        Button {
            Task {
                isRunning = true
                await action()
                isRunning = false
            }
        } label: {
            ButtonTitle(title: title, fontSize: 12, isLoading: isRunning)
                .padding(8)
                .background(Color(NSColor(hex: appState.preferences.branding.accentColor ?? "") ?? NSColor.controlAccentColor))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(disabled || isRunning)
    }
}

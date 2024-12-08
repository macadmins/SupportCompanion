//
//  CustomButtonView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import SwiftUI

struct CustomButton: View, Hashable {
    let title: String
    let action: () async -> Void
    let badgeNumber: Int?
    let helpText: String?
    let disabled: Bool?
    var maxWidth: CGFloat? // New parameter for button width
    let fontSize: CGFloat?
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var appState: AppStateManager
    @State private var isHovered = false
    @State private var showBadge = false
    @State private var isLoading = false

    init(
        _ title: String,
        badgeNumber: Int? = nil,
        helpText: String? = nil,
        disabled: Bool? = false,
        maxWidth: CGFloat? = nil,
        fontSize: CGFloat? = nil,
        action: @escaping @Sendable () async -> Void
    ) {
        self.title = title
        self.action = action
        self.badgeNumber = badgeNumber
        self.helpText = helpText
        self.disabled = disabled
        self.maxWidth = maxWidth
        self.fontSize = fontSize
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Main button
            Button(action: {
                Task {
                    let loadingTask = Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // Wait for 0.5 seconds
                        if !Task.isCancelled { // Only set isLoading if the action is still running
                            isLoading = true
                        }
                    }
                    
                    await action() // Run the actual action

                    // Cancel the loader delay task and hide the loader
                    loadingTask.cancel()
                    isLoading = false
                }
            }) {
                HStack {
                    // Button text
                    ButtonTitle(title: title, fontSize: fontSize, isLoading: isLoading)

                    // Loader to the right of the title
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.4)
                            .frame(width: 16, height: 16)
                            .padding(.leading, 3) // Add space between title and loader
                    }
                }
                .padding()
                .frame(maxWidth: maxWidth ?? nil) // Keep consistent button size
                .background(Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                .foregroundColor(.white)
                .cornerRadius(8)
                .multilineTextAlignment(.leading)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(disabled ?? false || isLoading)

            // Badge
            if let badgeNumber = badgeNumber, badgeNumber > 0 {
                Text("\(badgeNumber)")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.red)
                    .clipShape(Circle())
                    .offset(x: 10, y: -10)
                    .opacity(showBadge ? 1.0 : 0.0) // Control visibility
                    .scaleEffect(showBadge ? 1.0 : 0.5) // Add scaling effect
                    .animation(.easeInOut(duration: 0.3), value: showBadge) // Smooth animation
            }
        }
        .scaleEffect(isHovered ? 1.1 : 1.0) // Apply hover effect to the whole stack
        .shadow(color: .black.opacity(isHovered ? 0.3 : 0), radius: isHovered ? 10 : 0, x: 0, y: 5)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = !isLoading && hovering
        }
        .help(helpText ?? "")
        .onAppear {
            if let badgeNumber = badgeNumber, badgeNumber > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showBadge = true // Trigger badge animation on appear
                }
            }
        }
        .onChange(of: badgeNumber) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showBadge = (badgeNumber ?? 0) > 0
            }
        }
    }

    static func == (lhs: CustomButton, rhs: CustomButton) -> Bool {
        return lhs.title == rhs.title && lhs.badgeNumber == rhs.badgeNumber
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(badgeNumber)
    }
}

struct ButtonTitle: View {
    let title: String
    let fontSize: CGFloat?
    let isLoading: Bool
    
    var body: some View {
        Text(title)
            .font(fontSize != nil ? .system(size: fontSize!) : nil) // Use nil to skip applying a font
            .opacity(isLoading ? 0.5 : 1) // Dim the text slightly when loading
    }
}

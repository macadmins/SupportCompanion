//
//  DarkLightModeButton.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-21.
//
//NSAppearance.currentDrawing().bestMatch(from: [.aqua, .darkAqua])
import SwiftUI
import AppKit

struct DarkLightModeToggle: View {
    @AppStorage("isDarkMode") private var isDarkMode: Int = -1 // -1: System mode, 1: Dark, 0: Light
    @Environment(\.colorScheme) var colorScheme // Detect system theme
    @State private var currentSystemTheme: ColorScheme = .light // Track the current system theme

    var body: some View {
        ZStack {
            // Background of the toggle
            Capsule()
                .fill(LinearGradient(
                    gradient: Gradient(colors: resolvedTheme == .dark ? [.purple, .black] : [.yellow, .orange]),
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 50, height: 30)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                .overlay(
                    Capsule()
                        .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                )

            // Sliding Circle
            Circle()
                .fill(Color.white)
                .frame(width: 24, height: 24)
                .overlay(
                    Image(systemName: iconForTheme)
                        .foregroundColor(iconColor)
                        .scaleEffect(0.8)
                )
                .offset(x: circleOffset)
                .animation(.spring(), value: isDarkMode)
                .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
        }
        .onTapGesture {
            toggleAppearance()
        }
        .frame(width: 50, height: 30)
        .onAppear {
            updateAppAppearance()
            currentSystemTheme = colorScheme // Initialize system theme
        }
        .onChange(of: colorScheme) {
            currentSystemTheme = colorScheme // Update system theme on change
            if isDarkMode == -1 {
                updateAppAppearance()
            }
        }    }

    // MARK: - Resolved Theme
    private var resolvedTheme: ColorScheme {
        switch isDarkMode {
        case 1: return .dark
        case 0: return .light
        default: return currentSystemTheme
        }
    }

    // MARK: - Appearance Icon
    private var iconForTheme: String {
        switch isDarkMode {
        case 1: return "moon.fill"
        case 0: return "sun.max.fill"
        default: return "globe"
        }
    }

    private var iconColor: Color {
        switch isDarkMode {
        case 1: return .purple
        case 0: return .yellow
        default: return currentSystemTheme == .dark ? .purple : .yellow
        }
    }

    // MARK: - Circle Offset
    private var circleOffset: CGFloat {
        switch isDarkMode {
        case 1: return 10
        case 0: return -10
        default: return 0
        }
    }

    // MARK: - Toggle Appearance
    private func toggleAppearance() {
        if isDarkMode == -1 {
            // Start toggling from the system default
            isDarkMode = currentSystemTheme == .dark ? 0 : 1
        } else if isDarkMode == 0 {
            isDarkMode = 1
        } else {
            isDarkMode = -1
        }

        updateAppAppearance()
    }

    private func updateAppAppearance() {
        DispatchQueue.main.async {
            switch self.isDarkMode {
            case 1:
                NSApp.appearance = NSAppearance(named: .darkAqua)
            case 0:
                NSApp.appearance = NSAppearance(named: .aqua)
            default:
                NSApp.appearance = nil // Follow system
            }
        }
    }
}

struct DarkLightModeToggle_Previews: PreviewProvider {
    static var previews: some View {
        DarkLightModeToggle()
            .previewLayout(.sizeThatFits)
    }
}

//
//  CircularProgressWave.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-16.
//

import Foundation
import SwiftUI

struct WaveShape: Shape {
    var progress: CGFloat
    var waveHeight: CGFloat
    var phase: CGFloat

    var animatableData: CGFloat {
        get { phase }
        set { phase = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height * (1 - progress)

        // Extend sampling beyond the visible rect to avoid straight edge at the clip boundary
        let extra: CGFloat = max(12, width * 0.05)
        let startX: CGFloat = -extra
        let endX: CGFloat = width + extra

        // Use a smaller step for smoother appearance
        let step: CGFloat = 1

        var isFirstPoint = true
        var x = startX
        while x <= endX {
            let relativeX = x / width
            let sine = sin((relativeX + phase) * 2 * .pi)
            let y = midHeight + waveHeight * sine
            if isFirstPoint {
                path.move(to: CGPoint(x: x, y: y))
                isFirstPoint = false
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
            x += step
        }

        // Close the shape below; this will be clipped by a circle in the parent view
        path.addLine(to: CGPoint(x: endX, y: height))
        path.addLine(to: CGPoint(x: startX, y: height))
        path.closeSubpath()

        return path
    }
}

struct CircularProgressWithWave: View {
    @State private var phase: CGFloat = 0
    var progress: CGFloat
    var size: CGFloat
    var waveHeight: CGFloat
    var gradient: Gradient = Gradient(colors: [.blue, .purple])
    @Environment(\.colorScheme) var colorScheme // Access system light/dark mode
    @EnvironmentObject var appState: AppStateManager
    @State private var isAnimating = false // Track animation state

    var body: some View {
        ZStack {
            // Accent ring
            Circle()
                .stroke(
                    colorScheme == .dark 
                        ? Color(nsColor: .gray).opacity(0.5) 
                        : Color(nsColor: .gray).opacity(0.3), 
                    lineWidth: size * 0.02
                )// Thinner ring
                .frame(width: size, height: size)

            // Wave shape masked to a circle
            WaveShape(progress: progress, waveHeight: waveHeight, phase: phase)
                .fill(LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size) // Matches the full size of the ring
                .clipShape(Circle())
                .drawingGroup()
                .onAppear {
                    startAnimation()
                }
                .onDisappear {
                    stopAnimation()
                }
                .onChange(of: appState.windowIsVisible) { oldValue, newValue in
                    if newValue {
                        startAnimation()
                    } else {
                        stopAnimation()
                    }
                }

            // Progress text in the center
            Text("\(Int(progress * 100))%")
                .font(.largeTitle)
                .bold()
                .foregroundColor(colorScheme == .dark ? .white : .black) // Adapt text color
        }
        .frame(width: size, height: size)
    }

    private func startAnimation() {
        guard !isAnimating else { return } // Prevent duplicate animations
        isAnimating = true
        withAnimation(Animation.linear(duration: 4).repeatForever(autoreverses: false)) {
            phase = 1
        }
    }

    private func stopAnimation() {
        isAnimating = false
        phase = 0 // Reset phase to avoid lingering animation effects
    }
}


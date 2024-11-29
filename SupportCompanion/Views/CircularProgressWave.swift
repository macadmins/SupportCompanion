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

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, to: width, by: 2) {
            let relativeX = x / width
            let sine = sin((relativeX + phase) * 2 * .pi)
            let y = midHeight + waveHeight * sine
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
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
    var accentColor: Color = .gray.opacity(0.5) // Accent ring color
    @Environment(\.colorScheme) var colorScheme // Access system light/dark mode
    @EnvironmentObject var appState: AppStateManager
    @State private var isAnimating = false // Track animation state

    var body: some View {
        ZStack {
            // Accent ring
            Circle()
                .stroke(accentColor, lineWidth: size * 0.02) // Thinner ring
                .frame(width: size, height: size)

            // Wave shape masked to a circle
            WaveShape(progress: progress, waveHeight: waveHeight, phase: phase)
                .fill(LinearGradient(gradient: gradient, startPoint: .top, endPoint: .bottom))
                .frame(width: size, height: size) // Matches the full size of the ring
                .clipShape(Circle())
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

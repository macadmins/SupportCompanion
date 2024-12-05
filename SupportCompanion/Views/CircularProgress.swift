//
//  CircularProgressView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-13.
//

import Foundation
import SwiftUI

struct CircularProgress: View {
    var progress: Int
    var maxValue: Int
    var lineWidth: CGFloat
    var size: CGFloat
    var gradient: Gradient = Gradient(colors: [.blue, .purple]) // Customize colors

    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(lineWidth: lineWidth)
                .opacity(0.3)
                .foregroundColor(Color.gray)

            // Progress circle with smooth animation
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, maxValue)) / CGFloat(maxValue))
                .stroke(
                    LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
                .rotationEffect(Angle(degrees: 270))
                .animation(.easeInOut(duration: 1), value: progress) // Set duration

            // Progress text in the center
            Text("\(Int((Double(progress) / Double(maxValue)) * 100))%")
                .font(.largeTitle)
                .bold()
        }
        .frame(width: size, height: size)
    }
}

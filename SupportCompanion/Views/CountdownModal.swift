//
//  CountdownModal.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-18.
//

import Foundation
import SwiftUI

struct CountdownModal: View {
    @Binding var isPresented: Bool
    @State private var countdown: Int
    let title: String
    let message: String
    let onDismiss: () -> Void

    init(isPresented: Binding<Bool>, countdown: Int, title: String, message: String, onDismiss: @escaping () -> Void) {
        self._isPresented = isPresented
        self._countdown = State(initialValue: countdown)
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
    }

    var body: some View {
        ZStack {
            if isPresented {
                // Fullscreen background
                Color.black
                    .opacity(0.9)
                    .ignoresSafeArea()

                // Modal content
                VStack(spacing: 30) {
                    Spacer()

                    // Title
                    Text(title)
                        .font(.largeTitle)
                        .bold()
                        .foregroundColor(.white)

                    // Message
                    Text(message)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    // Countdown
                    Text("Closing in \(countdown) seconds...")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    // Dismiss button
                    Button(action: {
                        isPresented = false
                        onDismiss()
                    }) {
                        Text("Dismiss Now")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 250)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .onAppear {
            startCountdown()
        }
    }

    private func startCountdown() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                isPresented = false
                onDismiss()
            }
        }
    }
}

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
    @State private var timer: Timer?
    let title: String
    let message: String
    let onDismiss: () -> Void
    private let defaultCountdown: Int // Store the default countdown locally

    init(isPresented: Binding<Bool>, countdown: Int, title: String, message: String, onDismiss: @escaping () -> Void) {
        self._isPresented = isPresented
        self._countdown = State(initialValue: countdown)
        self.title = title
        self.message = message
        self.onDismiss = onDismiss
        self.defaultCountdown = countdown // Save the initial value
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
                    Text("Rebooting in \(countdown) seconds...")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))

                    // Dismiss button
                    Button(action: cancelCountdown) { // Call the new cancel function
                        Text("Cancel")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: 250)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(14)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            if newValue {
                resetAndStartCountdown()
            } else {
                cancelCountdown() // Clean up when modal closes
            }
        }
    }
    
    private func resetAndStartCountdown() {
        timer?.invalidate()
        timer = nil
        countdown = defaultCountdown // Reset the countdown
        startCountdown()
    }


    private func startCountdown() {
        // Stop and reset any previous timer to avoid duplication
        timer?.invalidate()
        timer = nil

        // Create a new timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if countdown > 0 {
                countdown -= 1
            } else {
                timer.invalidate()
                isPresented = false
                onDismiss()
            }
        }
    }

    private func cancelCountdown() {
        timer?.invalidate() // Stop the timer
        timer = nil         // Clear the timer reference
        countdown = defaultCountdown // Reset the internal countdown value
        isPresented = false // Hide the modal
        ActionHelpers.cancelShutdown()
        onDismiss()         // Notify the parent view (CardGrid) to reset the countdown
    }
}

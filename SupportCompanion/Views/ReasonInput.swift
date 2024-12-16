import SwiftUI
import AppKit

struct ReasonInputView: View {
    @State private var reason: String = ""
    @Binding var isPresented: Bool
    let onElevate: (String) -> Void
    private let appState = AppStateManager.shared

    var body: some View {
        VStack(spacing: 20) {
            Text("Enter Reason for Elevation")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Please provide a reason for elevating your privileges. This will be logged for auditing purposes.")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Styled Multiline TextEditor
            TextEditor(text: $reason)
                .frame(minHeight: 100, maxHeight: 150)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                )
                .shadow(radius: 1)
                .padding(.horizontal)
                .font(.system(size: 14))

            // Buttons
            HStack {
                Button("Cancel") {
                    // Dismiss the window                    
                    isPresented = false
                    ReasonInputManager.shared.closeWindow() // Explicitly close the window
                }
                .keyboardShortcut(.cancelAction)

                Button("Elevate") {
                    // Perform the elevation
                    onElevate(reason)
                    isPresented = false
                }
                .disabled(reason.count < appState.preferences.reasonMinLength)
                .padding()
            }
        }
        .padding()
        .frame(width: 550, height: 350)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

import SwiftUI
import AppKit

class ReasonInputManager {
    private var window: NSWindow?

    static let shared = ReasonInputManager()

    func presentAsWindow(isPresented: Binding<Bool>, onElevate: @escaping (String) -> Void) {
        guard window == nil else {
            return
        }

        let reasonInputView = ReasonInputView(
            isPresented: isPresented,
            onElevate: { reason in
                onElevate(reason)
                self.closeWindow()
            }
        )

        let hostingController = NSHostingController(rootView: reasonInputView)

        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        newWindow.contentView = hostingController.view
        newWindow.title = ""
        newWindow.styleMask = [.titled, .fullSizeContentView]
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)

        self.window = newWindow

        // Handle manual closure via delegate
        newWindow.delegate = WindowDelegate { [weak self] in
            self?.closeWindow()
        }
    }

    func closeWindow() {
        guard let window = window else {
            return
        }

        window.orderOut(nil) // Explicitly remove from the screen
        window.close()       // Close the window
        self.window = nil
    }
}

private class WindowDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}

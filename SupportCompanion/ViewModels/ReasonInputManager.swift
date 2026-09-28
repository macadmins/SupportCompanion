import AppKit
import SwiftUI

class ReasonInputManager {
    private var window: NSWindow?
    private var windowDelegate: WindowDelegate?

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

        let newWindow = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 350),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        newWindow.backgroundColor = .clear
        newWindow.isOpaque = false
        newWindow.contentView = hostingController.view
        newWindow.hasShadow = false
        newWindow.center()
        newWindow.ignoresMouseEvents = false
        newWindow.isMovableByWindowBackground = true
        newWindow.isReleasedWhenClosed = false
        newWindow.makeKeyAndOrderFront(nil)
        newWindow.makeFirstResponder(hostingController.view)

        self.window = newWindow

        let delegate = WindowDelegate { [weak self] in
            self?.closeWindow()
        }

        // Handle manual closure via delegate
        newWindow.delegate = delegate
        self.windowDelegate = delegate
    }

    func closeWindow() {
        guard let window = window else {
            return
        }

        // Clear state before closing: `close()` sends `windowWillClose`, which routes straight
        // back here, and re-entering with `window` still set would close the window twice.
        self.window = nil
        self.windowDelegate = nil
        window.delegate = nil
        window.orderOut(nil)
        window.close()
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

private class CustomWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

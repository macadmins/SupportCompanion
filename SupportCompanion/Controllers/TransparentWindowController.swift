import SwiftUI
import Combine
import AppKit

class TransparentWindowController: NSWindowController {
    private var appState: AppStateManager
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppStateManager) {
        self.appState = appState
        let initialSize = NSSize(width: 400, height: 500)
        let position = DesktopInfoPositionHelper.calculatePosition(
            for: appState.preferences.desktopInfoWindowPosition,
            windowSize: initialSize
        )

        let window = NSWindow(
            contentRect: NSRect(origin: position, size: initialSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.desktopWindow)))
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.appearance = NSAppearance(named: .darkAqua)

        super.init(window: window)

        // Content view setup
        let contentView = TransparentView()
            .environmentObject(appState)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            self.updateWindowFrame(size: geometry.size)
                        }
                        .onChange(of: geometry.size) { oldSize, newSize in
                            self.updateWindowFrame(size: newSize)
                        }
                }
            )
        
        window.contentView = NSHostingView(rootView: contentView)
        self.updateWindowPosition()

        // Manually observe position changes
        appState.preferences.$currentWindowPosition
            .sink { [weak self] newPosition in
                guard let self = self else { return }
                self.updateWindowPosition()
            }
            .store(in: &cancellables)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Updates both the size and position of the window
    private func updateWindowFrame(size: CGSize) {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            let position = DesktopInfoPositionHelper.calculatePosition(
                for: self?.appState.preferences.desktopInfoWindowPosition ?? "LowerRight",
                windowSize: size
            )
            window.setContentSize(size)
            let yOffset: CGFloat = self?.appState.preferences.desktopInfoWindowPosition.contains("Lower") == true ? 20 : -20
            window.setFrameOrigin(NSPoint(x: position.x, y: position.y + yOffset))
        }
    }

    private func updateWindowPosition() {
        DispatchQueue.main.async { [weak self] in
            guard let window = self?.window else { return }
            let position = DesktopInfoPositionHelper.calculatePosition(
                for: self?.appState.preferences.desktopInfoWindowPosition ?? "LowerRight",
                windowSize: window.frame.size
            )
            let yOffset: CGFloat = self?.appState.preferences.desktopInfoWindowPosition.contains("Lower") == true ? 20 : -20
            window.setFrameOrigin(NSPoint(x: position.x, y: position.y + yOffset))
        }
    }
}

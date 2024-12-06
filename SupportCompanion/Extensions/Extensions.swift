//
//  Extensions.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import AppKit
import SwiftUI

extension NSColor {
    /// Initializes an `NSColor` from a hex string (e.g., "#FF5733").
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.hasPrefix("#") ? String(hexSanitized.dropFirst()) : hexSanitized

        guard hexSanitized.count == 6,
              let rgbValue = UInt32(hexSanitized, radix: 16) else {
            return nil
        }

        let red = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
        let green = CGFloat((rgbValue & 0x00FF00) >> 8) / 255
        let blue = CGFloat(rgbValue & 0x0000FF) / 255

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

extension View {
    func sidebarItemStyle() -> some View {
        modifier(SidebarItemStyle())
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension ToastConfig {
    static func success(title: String, subTitle: String) -> ToastConfig {
        ToastConfig(
            isShowing: true,
            type: .complete(Color.green),
            title: title,
            subTitle: subTitle
        )
    }

    static func error(title: String, subTitle: String) -> ToastConfig {
        ToastConfig(
            isShowing: true,
            type: .error(Color.red),
            title: title,
            subTitle: subTitle
        )
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if AppDelegate.shouldExit {
            NSApplication.shared.terminate(nil)
        }
        Logger.shared.logDebug("Main window is closing.")
        AppStateManager.shared.windowIsVisible = false
        windowController = nil
        NSApp.setActivationPolicy(.accessory)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        AppStateManager.shared.windowIsVisible = true
    }
}

extension Notification.Name {
    static let handleIncomingURL = Notification.Name("handleIncomingURL")
}

extension Color {
    // Orange shades
    static let orangeLight = Color(hue: 0.1, saturation: 0.9, brightness: 0.75) // Softer orange for light mode
    
    // Red shades
    static let redLight = Color(hue: 0.02, saturation: 0.8, brightness: 0.7) // Softer red for light mode
}

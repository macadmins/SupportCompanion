//
//  Extensions.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-14.
//

import Foundation
import AppKit
import SwiftUI
import MarkdownUI

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
        AppStateManager.shared.jsonCardManager = nil
        NSApp.setActivationPolicy(.accessory)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        AppStateManager.shared.windowIsVisible = true
        BadgeManager.shared.incrementBadgeCount(count: AppStateManager.shared.pendingUpdatesCount + AppStateManager.shared.systemUpdateCache.count)
    }
}

extension Notification.Name {
    static let handleIncomingURL = Notification.Name("handleIncomingURL")
}

extension TimeInterval {
    /// Formats a TimeInterval into `hh:mm:ss` or `mm:ss`
    func formattedTime() -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    // func to format time to a string with "minutes" or "seconds" or "hourds" depending on the time
    func formattedTimeUnit() -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60

        if hours > 0 {
            let hourUnit = hours == 1 ? Constants.General.hour : Constants.General.hours
            return String(format: "%d \(hourUnit)", hours)
        } else if minutes > 0 {
            let minuteUnit = minutes == 1 ? Constants.General.minute : Constants.General.minutes
            return String(format: "%d \(minuteUnit)", minutes)
        } else {
            let secondUnit = seconds == 1 ? Constants.General.second : Constants.General.seconds
            return String(format: "%d \(secondUnit)", seconds)
        }
    }
}

extension Color {
    // Orange shades
    static let orangeLight = Color(hue: 0.1, saturation: 0.9, brightness: 0.75) // Softer orange for light mode
    
    // Red shades
    static let redLight = Color(hue: 0.02, saturation: 0.8, brightness: 0.7) // Softer red for light mode

    // Green shades
    static let ScGreen = Color(red: 0.1, green: 0.6, blue: 0.3)

    // Gray shades - darker gray for light mode
    static let grayLight = Color(hue: 0, saturation: 0, brightness: 0.3)
}

extension Theme {
    static let sc = Theme.basic
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(14)
                    }
                    .padding(12)
            }
            .background(Color.primary.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: 0, bottom: 12)
        }

        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.15))
                .relativeFrame(width: .em(0.2))
                configuration.label
                    .markdownTextStyle { ForegroundColor(.secondary) }
                .relativePadding(.horizontal, length: .em(1))
            }
            .fixedSize(horizontal: false, vertical: true)
        }

        .table { configuration in
            configuration.label
                .fixedSize(horizontal: false, vertical: true)
                .markdownTableBorderStyle(.init(color: .primary, width: 1))
                .markdownMargin(top: 16, bottom: 16)
                .markdownTableBackgroundStyle(
                    .alternatingRows(
                        Color.primary.opacity(0.1),
                        Color.clear, 
                        header: (Color(NSColor(hex: AppStateManager.shared.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                    )
                )
            }

        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    if configuration.row == 0 {
                        FontWeight(.semibold) // Make header bold
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 6)
                .padding(.horizontal, 13)
                .relativeLineSpacing(.em(0.25))
            }
}

extension View {
    @ViewBuilder
    func isGlass() -> some View {
        if #available(macOS 26, *) {
            self.glassEffect(in: .rect(cornerRadius: 12))
        }
        else {
            self.background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
            )
        }
    }
}

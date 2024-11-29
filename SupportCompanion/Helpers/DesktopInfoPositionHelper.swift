//
//  DesktopInfoPositionHelper.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 5024-11-24.
//

import Foundation
import SwiftUI

struct DesktopInfoPositionHelper {
    static func calculatePosition(for preference: String, windowSize: NSSize) -> NSPoint {
        //guard let screenFrame = NSScreen.main?.frame else { return .zero }
        
        guard let screenFrame = NSScreen.screens.first(where: { $0.frame.contains(NSPoint(x: 0, y: 0)) })?.frame
                ?? NSScreen.main?.frame else { return .zero }

        switch preference {
        case "LowerRight":
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - 50, // Padding from the right edge
                y: screenFrame.minY + 50 // Padding from the bottom edge
            )
        case "LowerLeft":
            return NSPoint(
                x: screenFrame.minX + 50, // Padding from the left edge
                y: screenFrame.minY + 50 // Padding from the bottom edge
            )
        case "UpperRight":
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - 50, // Padding from the right edge
                y: screenFrame.maxY - windowSize.height - 50 // Padding from the top edge
            )
        case "UpperLeft":
            return NSPoint(
                x: screenFrame.minX + 50, // Padding from the left edge
                y: screenFrame.maxY - windowSize.height - 50 // Padding from the top edge
            )
        default:
            // Lower right the window as fallback
            return NSPoint(
                x: screenFrame.maxX - windowSize.width - 50, // Padding from the right edge
                y: screenFrame.minY + 50 // Padding from the bottom edge
            )
        }
    }
}

//
//  Extensions.swift
//  SupportCompanionCLI
//
//  Created by Tobias Almén on 2024-12-18.
//

import Foundation
import SwiftUI

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
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

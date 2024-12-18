//
//  CardData.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import SwiftUI

struct CardData: View {
    @Environment(\.colorScheme) var colorScheme
    let info: [(key: String, display: String, value: InfoValue)]
    let customContent: (String, InfoValue) -> AnyView
    let fontSize: CGFloat?

    init(
        info: [(key: String, display: String, value: InfoValue)],
        customContent: @escaping (String, InfoValue) -> AnyView = { _, _ in AnyView(EmptyView()) },
        fontSize: CGFloat? = 14
    ) {
        self.info = info
        self.customContent = customContent
        self.fontSize = fontSize
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(info, id: \.key) { key, display, value in
                VStack(alignment: .leading, spacing: 5) {
                    // Display the key-value pair with formatting based on the key
                    defaultContent(for: key, display: display, value: value)
                    
                    // Insert custom content for specific labels
                    customContent(key, value)
                }
            }
        }
    }

    /// Provides the default content for a key-value pair
    private func defaultContent(for key: String, display: String, value: InfoValue) -> some View {
        HStack(alignment: .top) {
            Text(display)
                .fontWeight(.bold)
                .font(.system(size: fontSize ?? 14))

            switch key {
            case Constants.Battery.Keys.health:
                healthContent(value: value)
            case Constants.DeviceInfo.Keys.lastRestart:
                rebootContent(value: value.rawValue as? Int ?? 0)
            case "FileVault":
                fileVaultContent(value: value)
            case Constants.KerberosSSO.Keys.expiryDays:
                daysContent(value: value, suffix: " \(Constants.General.days)", color: colorForValue(key: key, value: value))
            case Constants.KerberosSSO.Keys.lastSSOPasswordChangeDays,
                 Constants.KerberosSSO.Keys.lastLocalPasswordChangeDays:
                daysContent(value: value, suffix: " \(Constants.General.daysAgo)")
            case Constants.Battery.Keys.temperature:
                temperatureContent(value: value)
            case Constants.PlatformSSO.Keys.registrationCompleted:
                pssoRegistrationContent(value: value)
            default:
                defaultText(value: value, key: key)
            }
        }
    }

    /// Displays health-specific content with color coding
    private func healthContent(value: InfoValue) -> some View {
        let color = colorForValue(key: Constants.Battery.Keys.health, value: value)
        
        return HStack(spacing: 0) {
            Text(value.displayValue)
                .foregroundColor(color)
                .font(.system(size: fontSize ?? 14))
            Text("%")
                .font(.system(size: fontSize ?? 14))
        }
    }
    
    private func temperatureContent(value: InfoValue) -> some View {
        let color = colorForValue(key: Constants.Battery.Keys.temperature, value: value)
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric
        
        return HStack(spacing: 0) {
            Text(value.displayValue)
                .foregroundColor(color)
                .font(.system(size: fontSize ?? 14))
            Text(usesMetric ? "°C" : "°F")
                .font(.system(size: fontSize ?? 14))
        }
    }

    /// Displays generic content with a suffix (e.g., "days")
    private func daysContent(value: InfoValue, suffix: String, color: Color = .primary) -> some View {
        Text(value.displayValue)
            .foregroundColor(color)
            .font(.system(size: fontSize ?? 14))
        + Text(suffix)
            .font(.system(size: fontSize ?? 14))
    }

    private func rebootContent(value: Int) -> some View {
        let formattedLastRestart = formattedRebootContent(value: value)
        return Text(formattedLastRestart)
            .foregroundColor(colorForLastRestart(value: value))
            .font(.system(size: fontSize ?? 14))
    }

    private func colorForLastRestart(value: Int) -> Color {
        let days = value / 1440
        switch days {
        case 0...2:
            return .ScGreen
        case 3...7:
            return colorScheme == .light ? .orangeLight : .orange
        default:
            return colorScheme == .light ? .redLight : .red
        }
    }
    
    private func pssoRegistrationContent(value: InfoValue) -> some View {
        return Text(value.displayValue)
            .foregroundColor(colorForValue(key: Constants.PlatformSSO.Keys.registrationCompleted, value: value))
            .font(.system(size: fontSize ?? 14))
    }

    /// Displays FileVault-specific content with icons
    private func fileVaultContent(value: InfoValue) -> some View {
        HStack {
            if value.displayValue == "Enabled" {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.ScGreen)
            } else {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor((colorScheme == .light ? .redLight : .red))
            }
            Text(value.displayValue)
                .font(.system(size: fontSize ?? 14))
        }
    }

    /// Displays default text with optional coloring
    private func defaultText(value: InfoValue, key: String) -> some View {
        Text(value.displayValue)
            .font(.system(size: fontSize ?? 14))
            .foregroundColor(colorForValue(key: key, value: value))
    }

    /// Determines the color for specific values.
    private func colorForValue(key: String, value: InfoValue) -> Color {
        let locale = Locale.current
        let usesMetric = locale.measurementSystem == .metric

        switch key {
        case "Health":
            if let intValue = value.rawValue as? Int {
                return intValue <= 30
                    ? (colorScheme == .light ? .redLight : .red)
                    : (intValue < 80
                        ? (colorScheme == .light ? .orangeLight : .orange)
                       : .ScGreen)
            }
        case "FileVault":
            if let boolValue = value.rawValue as? Bool {
                return !boolValue ? (colorScheme == .light ? .redLight : .red) : .ScGreen
            }
        case Constants.PlatformSSO.Keys.registrationCompleted:
            if let boolValue = value.rawValue as? Bool {
                return !boolValue ? (colorScheme == .light ? .redLight : .red) : .ScGreen
            }
        case Constants.KerberosSSO.Keys.expiryDays:
            if let intValue = value.rawValue as? Int {
                return intValue <= 30 ? (colorScheme == .light ? .orangeLight : .orange) : (intValue < 2 ? (colorScheme == .light ? .redLight : .red) : .ScGreen)
            }
        case Constants.Battery.Keys.temperature:
            if usesMetric {
                if let doubleValue = value.rawValue as? Double {
                    return doubleValue > 80 ? (colorScheme == .light ? .redLight : .red) : (doubleValue >= 60 ? (colorScheme == .light ? .orange : .orange) : .ScGreen)
                } else if let intValue = value.rawValue as? Int {
                    let temperature = Double(intValue)
                    return temperature > 80 ? (colorScheme == .light ? .redLight : .red) : (temperature >= 60 ? (colorScheme == .light ? .orangeLight : .orange) : .ScGreen)
                } else {
                    return .primary
                }
            } else {
                if let doubleValue = value.rawValue as? Double {
                    return doubleValue > 176 ? (colorScheme == .light ? .redLight : .red) : (doubleValue >= 140 ? (colorScheme == .light ? .orange : .orange) : .ScGreen)
                } else if let intValue = value.rawValue as? Int {
                    let temperature = Double(intValue)
                    return temperature > 176 ? (colorScheme == .light ? .redLight : .red) : (temperature >= 140 ? (colorScheme == .light ? .orangeLight : .orange) : .ScGreen)
                } else {
                    return .primary
                }
            }
        default:
            return .primary
        }
        return .primary
    }
}

//
//  Battrey.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import SwiftUI

struct BatteryInfo: Identifiable {
    let id: UUID
    let designCapacity: Int
    let maxCapacity: Int
    let cycleCount: Int
    let isCharging: String
    let temperature: Double
    let timeToFull: String
    
    var tempColor: Color {
        if temperature > 60 {
            return Color(NSColor.red)
        } else if temperature > 40 {
            return Color(NSColor.orange)
        } else {
            return Color(NSColor.green)
        }
    }
    
    private var healthPercentage: Int {
        if designCapacity > 0 {
            return Int(round((Double(maxCapacity) / Double(designCapacity)) * 100))
        } else {
            return 0
        }
    }
    
    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        let health = healthPercentage
        
        return [
            (
                key: Constants.Battery.Keys.health,
                display: Constants.Battery.Labels.health,
                value: .int(health)
            ),
            (
                key: Constants.Battery.Keys.cycleCount,
                display: Constants.Battery.Labels.cycleCount,
                value: .int(cycleCount)
            ),
            (
                key: Constants.Battery.Keys.temperature,
                display: Constants.Battery.Labels.temperature,
                value: .double(temperature)
            ),
            (
                key: Constants.Battery.Keys.isCharging,
                display: Constants.Battery.Labels.isCharging,
                value: .string(isCharging)
            ),
            (
                key: Constants.Battery.Keys.timeToFull,
                display: Constants.Battery.Labels.timeToFull,
                value: .string(timeToFull)
            )
        ]
    }
    
    func toKeyValuePairsCompact() -> [(key: String, display: String, value: InfoValue)] {
        let health = healthPercentage
        
        return [
            (
                key: Constants.Battery.Keys.health,
                display: Constants.Battery.Labels.health,
                value: .int(health)
            ),
            (
                key: Constants.Battery.Keys.temperature,
                display: Constants.Battery.Labels.temperature,
                value: .double(temperature)
            ),
            (
                key: Constants.Battery.Keys.timeToFull,
                display: Constants.Battery.Labels.timeToFull,
                value: .string(timeToFull)
            )
        ]
    }
}

//
//  Storage.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import SwiftUI

struct StorageInfo: Identifiable {
    let id: UUID
    let name: String
    let fileVault: Bool
    let usage: Double
    
    var percentageColor: Color {
        if usage > 80 {
            return Color(NSColor.red)
        } else if usage > 60 {
            return Color(NSColor.orange)
        } else {
            return Color(NSColor.green)
        }
    }
    
    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: Constants.Storage.Keys.name,
                display: Constants.Storage.Labels.name,
                value: .string(name)
            ),
            (
                key: "FileVault",
                display: "FileVault:",
                value: .bool(fileVault)
            )
        ]
    }
}

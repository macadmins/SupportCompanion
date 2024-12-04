//
//  InstalledApp.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-22.
//

import Foundation

struct InstalledApp: Identifiable {
    let id: UUID
    let name: String
    let version: String
    let action: String
    let arch: String
    let isSelfServe: Bool
    let path: String
    let type: String
    let bundleId: String
}

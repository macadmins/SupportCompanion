//
//  PendingMunkiUpdate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

struct PendingMunkiUpdate: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let version: String
    
    static func == (lhs: PendingMunkiUpdate, rhs: PendingMunkiUpdate) -> Bool {
        return lhs.id == rhs.id
    }
}

//
//  Updates.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-18.
//

import Foundation

struct SystemUpdates: Identifiable, Equatable {
    let id: UUID
    let count: Int
    let updates: [String]
    
    static func == (lhs: SystemUpdates, rhs: SystemUpdates) -> Bool {
        return lhs.count == rhs.count && lhs.updates == rhs.updates
    }
}

//
//  PendingIntuneUpdate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation

struct PendingIntuneUpdate: Identifiable, Equatable {
    let id: UUID
    let name: String
    let pendingReason: String
    let showInfoIcon: Bool
    let version: String
    
    static func == (lhs: PendingIntuneUpdate, rhs: PendingIntuneUpdate) -> Bool {
        return lhs.id == rhs.id
    }
}

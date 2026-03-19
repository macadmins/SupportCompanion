//
//  SidebarItem.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-17.
//

import Foundation
import SwiftUI

struct SidebarItem: Identifiable, Hashable, Equatable {
    let label: String
    let systemImage: String
    let destination: AnyView
    var badge: Int = 0

    var id: String { label }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        return lhs.id == rhs.id
    }
}

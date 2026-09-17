//
//  Action.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-23.
//

import Foundation

struct Action: Identifiable, Equatable, Hashable {
    let id: UUID
    let name: String
    let command: String
    let icon: String?
    let isPrivileged: Bool?
    let description: String?
    let buttonLabel: String?

    /// Everything except the id, for detecting whether a reloaded action list actually changed
    var contentKey: [String] {
        [name, command, icon ?? "", isPrivileged.map { String($0) } ?? "", description ?? "", buttonLabel ?? ""]
    }
}

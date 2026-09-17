//
//  PendingUpdate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-26.
//

import Foundation

protocol PendingUpdate: Identifiable where ID == UUID {
    var name: String { get }
    var version: String { get }
    /// Shown in an extra column when the manager defines `pendingUpdatesDetailColumnTitle`.
    var dueBy: String? { get }
}

extension PendingUpdate {
    var dueBy: String? { nil }
}

extension PendingMunkiUpdate: PendingUpdate {}
extension PendingIntuneUpdate: PendingUpdate {}
extension PendingJamfUpdate: PendingUpdate {}

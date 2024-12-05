//
//  PendingUpdate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-26.
//

import Foundation

protocol PendingUpdate: Identifiable {
    var name: String { get }
    var version: String { get }
}

extension PendingMunkiUpdate: PendingUpdate {}
extension PendingIntuneUpdate: PendingUpdate {}

//
//  PendingJamfUpdate.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-13.
//

import Foundation

struct PendingJamfUpdate: Identifiable, Equatable {
    let id: UUID
    let name: String
    let version: String
    let needsUpdate: Bool
    let label: UpdateLabel
    let details: String
	let showInfoIcon: Bool

    static func == (lhs: PendingJamfUpdate, rhs: PendingJamfUpdate) -> Bool {
        return lhs.id == rhs.id
    }
}

struct Policy {
    let id: Int
    let name: String
    let policyVersion: String?
    let installedOrUpdated: Date?
    let installStatus: Int?
	let iconUrl: String?
	let postInstallText: String?
}

struct Patch {
    let name: String
    let version: String
    let availableDate: Date?
    let deadlineDate: Date?
    let buttonText: String?
    let installStatus: Int?
}

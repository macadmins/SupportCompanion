//
//  PendingFleetUpdate.swift
//  SupportCompanion
//

import Foundation

/// A Fleet self-service title with a newer version available.
struct PendingFleetUpdate: PendingUpdate, Equatable {
    let titleID: Int
    let name: String
    let installedVersion: String
    let availableVersion: String

    /// Stable per title, so lists don't redraw every row on each refresh.
    var id: UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", titleID % 1_000_000_000_000)) ?? UUID()
    }

    var version: String { "\(installedVersion) → \(availableVersion)" }

    init?(title: FleetSoftwareTitle) {
        guard title.isUpdateAvailable,
              let installed = title.installedVersion,
              let available = title.availableVersion else { return nil }
        titleID = title.id
        name = title.title
        installedVersion = installed
        availableVersion = available
    }
}

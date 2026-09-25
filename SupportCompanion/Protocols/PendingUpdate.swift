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
    /// The installed application this update is for, when that is named differently from the update.
    ///
    /// Lets the Apps page pair an update with the app it belongs to without asking which mode is
    /// configured. Jamf needs it because the two names routinely differ — a patch called "Zoom Client
    /// for Meetings" updates an app Self Service lists as "zoom.us".
    var installedAppName: String? { get }
}

extension PendingUpdate {
    var dueBy: String? { nil }
    var installedAppName: String? { nil }
}

extension PendingMunkiUpdate: PendingUpdate {}
extension PendingIntuneUpdate: PendingUpdate {}

extension PendingJamfUpdate: PendingUpdate {
    var installedAppName: String? { policyName }
}

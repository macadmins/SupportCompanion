//
//  HelperProtocol.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

/// The operations the privileged helper will perform as root.
///
/// Every method is a named operation rather than a command to run. The helper decides what each one
/// executes, so a caller cannot ask it to run something of the caller's choosing, and the policy that
/// decides whether an operation is allowed at all is re-checked inside the helper against preferences
/// only an administrator can write. See `HelperPreferences`.
@objc(HelperProtocol)
public protocol HelperProtocol {

    // MARK: Elevation

    /// Add the connecting user to the `admin` group, and arm the root-side demotion timer.
    @objc func elevate(reason: String) async throws -> String

    /// Remove the connecting user from the `admin` group.
    @objc func demote() async throws -> String

    /// Seconds left before the helper demotes the connecting user, or 0 when no elevation is active.
    @objc func elevationTimeRemaining() async throws -> Double

    // MARK: Actions

    /// Run the `Command` of an administrator-defined action marked `IsPrivileged`.
    ///
    /// Only the name crosses the connection. The helper looks the action up itself, so the command it
    /// runs is always the one the administrator configured.
    @objc func runPrivilegedAction(named name: String) async throws -> String

    // MARK: Jamf

    @objc func jamfPatch(id: String) async throws -> String
    @objc func jamfSelfServicePatch(id: String, userId: String?) async throws -> String
    @objc func jamfRecon() async throws -> String

    /// Read one of the fixed Jamf log queries. `kind` is `checkIn` or `inventory`.
    @objc func jamfLog(kind: String, hours: Int) async throws -> String

    // MARK: Device management

    @objc func restartIntuneAgent() async throws -> String

    /// The install date of the MDM enrollment profile, as `yyyy-MM-dd`, or an empty string.
    @objc func mdmEnrollmentDate() async throws -> String

    // MARK: System

    @objc func reboot() async throws -> String
    @objc func cancelReboot() async throws -> String
    @objc func setIPConfigVerbose(_ enabled: Bool) async throws -> String
}

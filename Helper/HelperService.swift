//
//  HelperService.swift
//  com.github.macadmins.SupportCompanion.helper
//

import Foundation

/// The object exported over one validated connection.
///
/// One instance per connection, holding the identity of the process on the other end as the kernel
/// reported it in the audit token. Operations that act on "the user" act on that identity, so a client
/// cannot ask the helper to elevate somebody else.
final class HelperService: NSObject {

    private let clientUID: uid_t
    private let clientUserName: String

    init(clientUID: uid_t, clientUserName: String) {
        self.clientUID = clientUID
        self.clientUserName = clientUserName
        super.init()
    }

    /// Resolve a uid to a short user name, for `dseditgroup` and for finding managed preferences.
    static func userName(forUID uid: uid_t) -> String? {
        guard let entry = getpwuid(uid) else { return nil }
        return String(cString: entry.pointee.pw_name)
    }
}

// MARK: - Validation

extension HelperService {

    /// Jamf ids are numbers. They reach the command as a separate argument rather than inside a shell
    /// string, so this is belt and braces, but a malformed id is a bug worth refusing either way.
    private func validatedJamfID(_ id: String) throws -> String {
        guard !id.isEmpty, id.allSatisfy(\.isNumber) else {
            throw SupportCompanionErrors.helperConnection("'\(id)' is not a valid Jamf id")
        }

        return id
    }

    private func validatedUserID(_ userId: String?) throws -> String? {
        guard let userId, !userId.isEmpty else { return nil }

        guard !userId.contains(where: { $0.isNewline || $0 == "\0" }) else {
            throw SupportCompanionErrors.helperConnection("Jamf user id contains illegal characters")
        }

        return userId
    }

    /// Reduce a client-supplied file name to something safe to log and to derive an extension from.
    ///
    /// Only ever used for display, for the log, and for its extension — never to build a path to read
    /// from. The staging file is named by the helper. See `StagedFile.copy(from:toDirectory:fileName:)`.
    private func sanitizedFileName(_ fileName: String) throws -> String {
        let name = (fileName as NSString).lastPathComponent
            .unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) || $0 == "/" ? " " : Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, name != ".", name != ".." else {
            throw SupportCompanionErrors.helperConnection("'\(fileName)' is not a usable file name")
        }

        return String(name.prefix(255))
    }

    /// Refuse to act on root or on a uid with no account behind it.
    private func validatedElevationTarget() throws -> String {
        guard clientUID != 0 else {
            throw SupportCompanionErrors.helperConnection("Refusing to change group membership for root")
        }

        guard !clientUserName.isEmpty else {
            throw SupportCompanionErrors.helperConnection("No user account for uid \(clientUID)")
        }

        return clientUserName
    }
}

// MARK: - HelperProtocol

extension HelperService: HelperProtocol {

    // MARK: Elevation

    func elevate(reason: String) async throws -> String {
        let userName = try validatedElevationTarget()

        // The app hides the button when elevation is off, but that is presentation. This is the check
        // that decides, and it reads a preference only an administrator can write.
        guard HelperPreferences.bool(forKey: "EnableElevation", default: false, forUser: userName) else {
            Logger.shared.logError("Refusing to elevate \(userName): EnableElevation is not set by an administrator")
            throw SupportCompanionErrors.helperConnection("Elevation is not enabled by an administrator")
        }

        let maximumMinutes = HelperPreferences.int(forKey: "MaxElevationTime", default: 5, forUser: userName)

        return try await ElevationCoordinator.shared.elevate(
            userName: userName,
            reason: reason,
            maximumMinutes: maximumMinutes
        )
    }

    func demote() async throws -> String {
        let userName = try validatedElevationTarget()
        return try await ElevationCoordinator.shared.demote(userName: userName)
    }

    func elevationTimeRemaining() async throws -> Double {
        ElevationCoordinator.shared.timeRemaining(userName: clientUserName)
    }

    // MARK: Actions

    func runPrivilegedAction(named name: String) async throws -> String {
        guard let command = HelperPreferences.privilegedActionCommand(named: name, forUser: clientUserName) else {
            throw SupportCompanionErrors.helperConnection("No privileged action named '\(name)' is configured by an administrator")
        }

        Logger.shared.logInfo("Running privileged action '\(name)' for \(clientUserName)")

        return try await ExecutionService.shell(command)
    }

    // MARK: User installs

    func stageInstaller(_ installer: FileHandle, fileName: String) async throws -> String {
        guard clientUID != 0, !clientUserName.isEmpty else {
            throw SupportCompanionErrors.helperConnection("No user account for uid \(clientUID)")
        }

        let name = try sanitizedFileName(fileName)

        Logger.shared.logInfo("Assessing installer '\(name)' for \(clientUserName)")

        let assessment = try await InstallCoordinator.shared.stage(
            from: installer,
            fileName: name,
            clientUID: clientUID,
            clientUserName: clientUserName
        )

        return try assessment.jsonString()
    }

    func installStagedInstaller(token: String) async throws -> String {
        guard UUID(uuidString: token) != nil else {
            throw SupportCompanionErrors.helperConnection("That is not a staged installer")
        }

        Logger.shared.logInfo("Installing staged installer for \(clientUserName)")

        return try await InstallCoordinator.shared.install(
            token: token,
            clientUID: clientUID,
            clientUserName: clientUserName
        )
    }

    func discardStagedInstaller(token: String) async throws -> String {
        guard UUID(uuidString: token) != nil else {
            throw SupportCompanionErrors.helperConnection("That is not a staged installer")
        }

        await InstallCoordinator.shared.discard(token, clientUID: clientUID)

        return ""
    }

    // MARK: Jamf

    func jamfPatch(id: String) async throws -> String {
        let id = try validatedJamfID(id)
        return try await ExecutionService.run("/usr/local/bin/jamf", ["patch", "-id", id])
    }

    func jamfSelfServicePatch(id: String, userId: String?) async throws -> String {
        let id = try validatedJamfID(id)

        var arguments = [
            "asuser", String(clientUID),
            "/usr/local/bin/jamf", "patch", "-id", id, "-showSteps", "-selfServiceOnly"
        ]

        if let userId = try validatedUserID(userId) {
            arguments += ["-user", userId]
        }

        return try await ExecutionService.run("/bin/launchctl", arguments)
    }

    func jamfRecon() async throws -> String {
        try await ExecutionService.run("/usr/local/bin/jamf", ["recon", "-concurrent"])
    }

    func jamfLog(kind: String, hours: Int) async throws -> String {
        let predicate: String

        switch kind {
        case "checkIn":
            predicate = #"process == "jamf" AND eventMessage CONTAINS "recurring check-in""#
        case "inventory":
            predicate = #"process == "jamf" AND eventMessage CONTAINS "Submitting data""#
        default:
            throw SupportCompanionErrors.helperConnection("Unknown Jamf log query '\(kind)'")
        }

        let clampedHours = min(max(hours, 1), 168)

        return try await ExecutionService.run("/usr/bin/log", [
            "show",
            "--predicate", predicate,
            "--last", "\(clampedHours)h",
            "--style", "syslog"
        ])
    }

    // MARK: Device management

    func restartIntuneAgent() async throws -> String {
        try await ExecutionService.run("/usr/bin/killall", ["IntuneMdmAgent"])
    }

    func mdmEnrollmentDate() async throws -> String {
        // Find the enrollment profile by its com.apple.mdm payload rather than by name, since every MDM
        // names it differently (Jamf "MDM Profile", Intune "Management Profile", …). The pipeline is
        // fixed here in the helper; nothing in it comes from the connection.
        let installDate = #"(//dict[key[.='PayloadType']/following-sibling::*[1][.='com.apple.mdm']])[1]/../../key[.='ProfileInstallDate']/following-sibling::*[1]/text()"#
        let command = #"/usr/bin/profiles -C -o stdout-xml | /usr/bin/xmllint --xpath "\#(installDate)" - 2>/dev/null || true"#

        let output = try await ExecutionService.shell(command)

        guard let range = output.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) else {
            return ""
        }

        return String(output[range])
    }

    // MARK: System

    func reboot() async throws -> String {
        try await ExecutionService.run("/sbin/shutdown", ["-r", "+1"])
    }

    func cancelReboot() async throws -> String {
        try await ExecutionService.run("/usr/bin/killall", ["shutdown"])
    }

    func setIPConfigVerbose(_ enabled: Bool) async throws -> String {
        try await ExecutionService.run("/usr/sbin/ipconfig", ["setverbose", enabled ? "1" : "0"])
    }
}

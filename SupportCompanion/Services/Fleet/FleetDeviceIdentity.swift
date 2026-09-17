//
//  FleetDeviceIdentity.swift
//  SupportCompanion
//
//  Finds the Fleet server and this device's token, as installed by Fleet's agent (orbit).
//

import Foundation

enum FleetDeviceIdentity {
    /// Written by orbit, world-readable, rotated about every hour.
    static let tokenPath = "/opt/orbit/identifier"
    static let orbitDaemonPlistPath = "/Library/LaunchDaemons/com.fleetdm.orbit.plist"
    static let logFolder = "/var/log/orbit"

    static var isOrbitInstalled: Bool {
        FileManager.default.fileExists(atPath: tokenPath)
    }

    /// The Fleet server URL.
    ///
    /// The device token is sent to this server, so it only comes from sources a standard user can't change:
    /// the `FleetUrl` preference when set by an administrator (see TrustedPreferences), or the
    /// `ORBIT_FLEET_URL` orbit was installed with in its root-owned LaunchDaemon.
    static func serverURL() -> URL? {
        let override = TrustedPreferences.string(forKey: "FleetUrl", default: "")
        if let url = validServerURL(override) {
            return url
        }

        guard let plist = NSDictionary(contentsOfFile: orbitDaemonPlistPath),
              let environment = plist["EnvironmentVariables"] as? [String: Any],
              let orbitURL = environment["ORBIT_FLEET_URL"] as? String else {
            return nil
        }
        return validServerURL(orbitURL)
    }

    struct Token: Equatable, Sendable {
        let value: String
        let modified: Date
    }

    /// Reads the current device token, or nil when orbit hasn't written one.
    static func readToken() -> Token? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: tokenPath),
              let modified = attributes[.modificationDate] as? Date,
              let contents = try? String(contentsOfFile: tokenPath, encoding: .utf8) else {
            return nil
        }
        let value = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : Token(value: value, modified: modified)
    }

    /// Modification date of the token file, to detect rotation without reading it.
    static func tokenModificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: tokenPath))?[.modificationDate] as? Date
    }

    private static func validServerURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https", url.host != nil else {
            return nil
        }
        return url
    }
}

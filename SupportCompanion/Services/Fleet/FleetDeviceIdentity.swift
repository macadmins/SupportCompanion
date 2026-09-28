//
//  FleetDeviceIdentity.swift
//  SupportCompanion
//
//  Finds the Fleet server and this device's token, as installed by Fleet's agent (orbit).
//  Mirrors how Fleet's own macOS Fleet Desktop app (apps/fleet-desktop-macos) resolves them.
//

import Foundation

enum FleetDeviceIdentity {
    /// Written by orbit, world-readable, rotated about every hour.
    static let tokenPath = "/opt/orbit/identifier"
    /// Fleet URL on Macs where Fleet is the MDM, delivered in a configuration profile.
    static let fleetdConfigPlistPath = "/Library/Managed Preferences/com.fleetdm.fleetd.config.plist"
    /// Fleet URL when orbit was installed from a package built with `fleetctl package`.
    static let orbitDaemonPlistPath = "/Library/LaunchDaemons/com.fleetdm.orbit.plist"
    static let logFolder = "/var/log/orbit"

    static var isOrbitInstalled: Bool {
        FileManager.default.fileExists(atPath: tokenPath)
    }

    /// The Fleet server URL.
    ///
    /// The device token is sent to this server, so it only comes from sources a standard user can't change,
    /// in order: the `FleetUrl` preference when set by an administrator (see TrustedPreferences), the
    /// `FleetURL` in fleetd's MDM configuration profile, or the `ORBIT_FLEET_URL` in orbit's LaunchDaemon.
    static func serverURL() -> URL? {
        for candidate in serverURLCandidates() {
            if let url = validServerURL(candidate) {
                return url
            }
        }
        return nil
    }

    struct Token: Equatable, Sendable {
        let value: String
        let modified: Date
    }

    /// Reads the current device token, or nil when orbit hasn't written a valid one.
    static func readToken() -> Token? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: tokenPath),
              let modified = attributes[.modificationDate] as? Date,
              let contents = FileManager.default.contents(atPath: tokenPath),
              let value = String(data: contents, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              isValidToken(value) else {
            return nil
        }
        return Token(value: value, modified: modified)
    }

    /// Modification date of the token file, to detect rotation without reading it.
    static func tokenModificationDate() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: tokenPath))?[.modificationDate] as? Date
    }

    /// Why Fleet can't be used on this Mac, or nil when it can. Safe to log and show: it never includes the token.
    static func configurationProblem() -> String? {
        if !isOrbitInstalled {
            return "Fleet's agent (orbit) isn't installed: \(tokenPath) doesn't exist."
        }
        if readToken() == nil {
            return "The device token at \(tokenPath) couldn't be read or isn't valid."
        }
        let candidates = serverURLCandidates()
        if candidates.isEmpty {
            return "No Fleet server URL found in \(fleetdConfigPlistPath) (FleetURL) or \(orbitDaemonPlistPath) (ORBIT_FLEET_URL)."
        }
        if serverURL() == nil {
            return "The configured Fleet server URL must be a valid HTTPS URL."
        }
        return nil
    }

    // MARK: - Private

    /// Configured URLs in priority order, before validation.
    private static func serverURLCandidates() -> [String] {
        var candidates: [String] = []

        let override = TrustedPreferences.string(forKey: "FleetUrl", default: "")
        if !override.isEmpty {
            candidates.append(override)
        }

        if let config = NSDictionary(contentsOfFile: fleetdConfigPlistPath),
           let url = config["FleetURL"] as? String, !url.isEmpty {
            candidates.append(url)
        }

        if let plist = NSDictionary(contentsOfFile: orbitDaemonPlistPath),
           let environment = plist["EnvironmentVariables"] as? [String: Any],
           let url = environment["ORBIT_FLEET_URL"] as? String, !url.isEmpty {
            candidates.append(url)
        }

        return candidates
    }

    private static func validServerURL(_ string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url
    }

    /// ASCII letters, digits, `-` and `_` only, so a token can't add path segments or other URL syntax
    /// to the device URLs built from it.
    private static let tokenCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    /// Also used for other ids Fleet returns that go into request paths.
    static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.unicodeScalars.allSatisfy { tokenCharacters.contains($0) }
    }
}

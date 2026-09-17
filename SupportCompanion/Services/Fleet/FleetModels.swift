//
//  FleetModels.swift
//  SupportCompanion
//
//  Response types for Fleet's device-authenticated API (/api/v1/fleet/device/{token}/…).
//  Decoded with `.convertFromSnakeCase`, so property names are the camel-cased JSON keys.
//

import Foundation

// MARK: - Software

enum FleetInstallStatus: String, Decodable, Sendable {
    case installed
    case pendingInstall = "pending_install"
    case failedInstall = "failed_install"
    case pendingUninstall = "pending_uninstall"
    case failedUninstall = "failed_uninstall"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = FleetInstallStatus(rawValue: raw) ?? .unknown
    }
}

struct FleetInstalledVersion: Decodable, Equatable, Sendable {
    let version: String
    let bundleIdentifier: String?
    let installedPaths: [String]?
}

struct FleetLastInstall: Decodable, Equatable, Sendable {
    let installUuid: String?
    let commandUuid: String?
    let installedAt: Date?
}

struct FleetLastUninstall: Decodable, Equatable, Sendable {
    let scriptExecutionId: String?
    let uninstalledAt: Date?
}

/// A software package or App Store app that Fleet can install for a title.
struct FleetInstaller: Decodable, Equatable, Sendable {
    let name: String?
    let version: String?
    let platform: String?
    let selfService: Bool?
    let categories: [String]?
    let lastInstall: FleetLastInstall?
    let lastUninstall: FleetLastUninstall?
    let hasUninstallScript: Bool?
    let appStoreId: String?
}

struct FleetSoftwareTitle: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let displayName: String?
    let bundleIdentifier: String?
    let iconUrl: String?
    let source: String?
    let status: FleetInstallStatus?
    /// Set with a `failed_install` status when Fleet skipped a patch-when-closed install because the app was open.
    let skippedInstall: Bool?
    let installedVersions: [FleetInstalledVersion]?
    let softwarePackage: FleetInstaller?
    let appStoreApp: FleetInstaller?

    enum Action: Equatable, Sendable {
        case install
        case update
        case reinstall
        case uninstall
    }

    var title: String {
        if let displayName, !displayName.isEmpty { return displayName }
        return name
    }

    var installer: FleetInstaller? { softwarePackage ?? appStoreApp }

    var bundleIdentifiers: [String] {
        ([bundleIdentifier] + (installedVersions ?? []).map(\.bundleIdentifier)).compactMap { $0 }.filter { !$0.isEmpty }
    }

    var categories: [String] { installer?.categories ?? [] }

    /// Highest installed version, if any version is installed.
    var installedVersion: String? {
        installedVersions?
            .map(\.version)
            .filter { !$0.isEmpty }
            .max { FleetVersion.isOlder($0, than: $1) }
    }

    var availableVersion: String? {
        guard let version = installer?.version, !version.isEmpty else { return nil }
        return version
    }

    var isInstalled: Bool {
        status == .installed || installedVersion != nil
    }

    /// Whether the installed version is older than Fleet's, including while the update is being installed.
    var isUpdateAvailable: Bool {
        guard let installedVersion, let availableVersion else { return false }
        return FleetVersion.isOlder(installedVersion, than: availableVersion)
    }

    var isPending: Bool {
        status == .pendingInstall || status == .pendingUninstall
    }

    var hasFailed: Bool {
        status == .failedInstall || status == .failedUninstall
    }

    /// Fleet generates uninstall scripts for packages; App Store apps can't be uninstalled from self-service.
    var canUninstall: Bool {
        isInstalled && softwarePackage != nil && softwarePackage?.hasUninstallScript != false
    }

    /// Installing the same version again, as Fleet's self-service page offers for installed titles.
    var canReinstall: Bool {
        isInstalled && !isUpdateAvailable && installer != nil
    }

    /// Whether the title is one of the keys in a preference: its id as a string, or its display name or
    /// name in any case.
    func matches(_ key: String) -> Bool {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return false }
        if key == String(id) { return true }
        return [displayName, name].contains { $0.map { $0.caseInsensitiveCompare(key) == .orderedSame } ?? false }
    }

    /// The main action offered for this title, or nil while an action is pending.
    var primaryAction: Action? {
        guard !isPending, installer != nil else { return nil }
        if isUpdateAvailable { return .update }
        if !isInstalled { return .install }
        return nil
    }
}

struct FleetSoftwareCategory: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
}

// MARK: - Results

struct FleetInstallResult: Decodable, Sendable {
    let installUuid: String?
    let softwareTitle: String?
    let softwareTitleId: Int?
    let status: FleetInstallStatus?
    let output: String?
    let preInstallQueryOutput: String?
    let postInstallScriptOutput: String?
}

/// Result of an uninstall script run.
struct FleetScriptResult: Decodable, Sendable {
    let executionId: String?
    let output: String?
    let message: String?
    let exitCode: Int?
}

// MARK: - Policies

struct FleetPolicy: Decodable, Identifiable, Equatable, Sendable {
    let id: Int
    let name: String
    let description: String?
    let resolution: String?
    let critical: Bool?
    /// "pass", "fail", or empty when the policy hasn't run on this host yet.
    let response: String?

    var isFailing: Bool { response == "fail" }
}

// MARK: - Host

/// This Mac's record in Fleet, from `GET /device/{token}`.
struct FleetHost: Decodable, Equatable, Sendable {
    let id: Int
    let hostname: String?
    let computerName: String?
    let seenTime: Date?
    let detailUpdatedAt: Date?
    let policyUpdatedAt: Date?
    let lastEnrolledAt: Date?
    let teamName: String?
    /// Newer Fleet versions call teams fleets.
    let fleetName: String?
    let orbitVersion: String?
    let osqueryVersion: String?
    let fleetDesktopVersion: String?
    /// Set after a refetch until the host has sent fresh details.
    let refetchRequested: Bool?
    let policies: [FleetPolicy]?

    var team: String? { [teamName, fleetName].compactMap { $0 }.first { !$0.isEmpty } }

    /// Fleet sends Go's zero time (year 1) for events that haven't happened.
    static func realDate(_ date: Date?) -> Date? {
        guard let date, date > Date(timeIntervalSince1970: 0) else { return nil }
        return date
    }
}

struct FleetDeviceHostResponse: Decodable, Sendable {
    let host: FleetHost
}

// MARK: - Desktop summary

struct FleetDesktopSummary: Decodable, Sendable {
    let failingPoliciesCount: Int?
    let selfService: Bool?
}

// MARK: - Response envelopes

struct FleetSoftwareListResponse: Decodable, Sendable {
    struct Meta: Decodable, Sendable {
        let hasNextResults: Bool?
    }

    let software: [FleetSoftwareTitle]
    let count: Int?
    let meta: Meta?
}

struct FleetCategoriesResponse: Decodable, Sendable {
    let selfServiceCategories: [FleetSoftwareCategory]
}

struct FleetInstallResultsResponse: Decodable, Sendable {
    let results: FleetInstallResult?
}

struct FleetPoliciesResponse: Decodable, Sendable {
    let policies: [FleetPolicy]
}

/// Fleet's error body. `ssoRequired` is set when Fleet Desktop SSO is enabled and no session cookie was sent.
struct FleetErrorResponse: Decodable, Sendable {
    struct Detail: Decodable, Sendable {
        let name: String?
        let reason: String?
    }

    let message: String?
    let errors: [Detail]?
    let ssoRequired: Bool?

    var summary: String {
        let reasons = (errors ?? []).compactMap(\.reason).filter { !$0.isEmpty }
        return reasons.isEmpty ? (message ?? "") : reasons.joined(separator: " ")
    }
}

// MARK: - Versions

enum FleetVersion {
    /// Numeric-aware comparison, so "4.9" is older than "4.10".
    static func isOlder(_ lhs: String, than rhs: String) -> Bool {
        lhs.compare(rhs, options: .numeric) == .orderedAscending
    }
}

// MARK: - Decoding

extension JSONDecoder {
    static let fleet: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let string = try decoder.singleValueContainer().decode(String.self)
            let fractional = ISO8601DateFormatter()
            fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = fractional.date(from: string) ?? ISO8601DateFormatter().date(from: string) {
                return date
            }
            // Go can send more fractional digits than ISO8601DateFormatter reads
            let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
            if let date = ISO8601DateFormatter().date(from: trimmed) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(string)"))
        }
        return decoder
    }()
}

//
//  InstallerPolicy.swift
//  SupportCompanion
//
//  Shared by the app and the privileged helper.
//

import Foundation

// MARK: - Match mode

/// How an allowlist entry recognises the installer the administrator meant.
public enum InstallerMatchMode: String, Codable, Sendable {
    /// The file's SHA-256 must be exactly the one in the profile. Pins one build; survives no update.
    case strict
    /// The signature must be the organisation's: a Team ID, and normally an identifier as well.
    case signature
}

// MARK: - Allowlist entry

/// One application an administrator has allowed a standard user to install.
///
/// Parsed from the `AllowedInstallers` preference, which is only ever read from a root-owned file. See
/// `HelperPreferences`.
public struct AllowedInstaller: Sendable {

    public let name: String

    /// The Developer ID team the installer must be signed by. Required in `.signature` mode.
    public let teamID: String?

    /// Package identifiers this entry accepts, for a `.pkg`.
    public let packageIdentifiers: [String]

    /// Bundle identifiers this entry accepts, for the app inside a `.dmg`.
    public let bundleIdentifiers: [String]

    /// The exact digest of the installer file, for `.strict` mode.
    public let sha256: String?

    /// The SHA-256 of the signing certificate itself, as an optional extra pin.
    ///
    /// A Team ID is read out of a certificate's subject, which is a human-readable string; this is the
    /// certificate. Stricter than `TeamID` and unambiguous in a way a name is not — at the cost of
    /// needing an update whenever the vendor renews, which is why it is never required.
    public let leafCertificateSHA256: String?

    /// Refuse anything older than this, so a signed-but-vulnerable build cannot be installed instead.
    public let minimumVersion: String?

    public let requireNotarized: Bool

    /// Whether a package carrying pre/postinstall scripts is acceptable.
    ///
    /// Off by default, and the single most useful restriction here: a scriptless package whose payload
    /// lands in `/Applications` is a file copy, while one with a postinstall script is arbitrary code as
    /// root on every future build the vendor signs.
    public let allowScripts: Bool

    /// Where this installer is allowed to write, as absolute path prefixes.
    ///
    /// `nil` leaves it unrestricted, which is the default because enumerating paths for every app is
    /// more than most administrators will do. Setting it is what bounds the damage when an entry is
    /// written loosely: an allowlisted package is otherwise free to drop a LaunchDaemon while
    /// installing the app that was actually approved.
    public let allowedPayloadPrefixes: [String]?

    /// Let this installer write anywhere, including the places `InstallerPolicy.protectedPrefixes`
    /// otherwise keeps back.
    ///
    /// Its own key rather than `AllowedPayloadPrefixes: ["/"]`, so the most dangerous setting is one
    /// somebody has to mean, not one they can reach by typing a prefix wrong.
    public let allowUnrestrictedPayload: Bool

    /// Accept anything signed by `teamID`, whatever it identifies itself as.
    ///
    /// Spelled out rather than inferred from a missing identifier, because the two are very different
    /// intentions and only one of them should be reachable by leaving a key out of a profile by mistake.
    /// This is a vendor allowlist: it covers every installer that team will ever sign, not one app.
    public let allowAnyIdentifier: Bool

    public var mode: InstallerMatchMode { sha256 == nil ? .signature : .strict }

    public init(
        name: String,
        teamID: String?,
        packageIdentifiers: [String],
        bundleIdentifiers: [String],
        sha256: String?,
        leafCertificateSHA256: String? = nil,
        minimumVersion: String?,
        requireNotarized: Bool,
        allowScripts: Bool,
        allowAnyIdentifier: Bool,
        allowedPayloadPrefixes: [String]? = nil,
        allowUnrestrictedPayload: Bool = false
    ) {
        self.name = name
        self.teamID = teamID
        self.packageIdentifiers = packageIdentifiers
        self.bundleIdentifiers = bundleIdentifiers
        self.sha256 = sha256
        self.leafCertificateSHA256 = leafCertificateSHA256
        self.minimumVersion = minimumVersion
        self.requireNotarized = requireNotarized
        self.allowScripts = allowScripts
        self.allowAnyIdentifier = allowAnyIdentifier
        self.allowedPayloadPrefixes = allowedPayloadPrefixes
        self.allowUnrestrictedPayload = allowUnrestrictedPayload
    }
}

// MARK: - Parsing

extension AllowedInstaller {

    /// Build an entry from one dictionary in the `AllowedInstallers` array.
    ///
    /// Returns `nil` for an entry that cannot decide anything, rather than one that decides too much:
    /// an entry with no `SHA256` and no `TeamID` would otherwise match on nothing at all.
    public static func make(from dictionary: [String: Any]) -> (
        entry: AllowedInstaller?, problem: String?
    ) {
        let name = (dictionary["Name"] as? String)?.trimmed ?? ""
        let label = name.isEmpty ? "<unnamed>" : name

        guard !name.isEmpty else {
            return (nil, "an entry has no Name")
        }

        let sha256 = (dictionary["SHA256"] as? String)?.trimmed.lowercased()
        let teamID = (dictionary["TeamID"] as? String)?.trimmed

        if let sha256, sha256.count != 64 || !sha256.allSatisfy(\.isHexDigit) {
            return (nil, "'\(label)' has a SHA256 that is not a 64-character hex digest")
        }

        let leafCertificateSHA256 = (dictionary["LeafCertificateSHA256"] as? String)?
            .replacingOccurrences(of: " ", with: "")
            .trimmed
            .lowercased()

        if let leafCertificateSHA256,
           leafCertificateSHA256.count != 64 || !leafCertificateSHA256.allSatisfy(\.isHexDigit) {
            return (nil, "'\(label)' has a LeafCertificateSHA256 that is not a 64-character hex digest")
        }

        let packageIdentifiers = stringList(dictionary["PackageIdentifier"])
        let bundleIdentifiers = stringList(dictionary["BundleIdentifier"])
        let allowAnyIdentifier = boolean(dictionary["AllowAnyIdentifier"], default: false)

        if sha256 == nil {
            guard let teamID, !teamID.isEmpty else {
                return (nil, "'\(label)' has neither a SHA256 nor a TeamID, so it can never match")
            }

            guard allowAnyIdentifier || !packageIdentifiers.isEmpty || !bundleIdentifiers.isEmpty
            else {
                return (
                    nil,
                    "'\(label)' has a TeamID but no PackageIdentifier or BundleIdentifier. Add one, or set AllowAnyIdentifier to allow everything that team signs"
                )
            }
        }

        return (
            AllowedInstaller(
                name: name,
                teamID: teamID?.isEmpty == true ? nil : teamID,
                packageIdentifiers: packageIdentifiers,
                bundleIdentifiers: bundleIdentifiers,
                sha256: sha256,
                leafCertificateSHA256: leafCertificateSHA256,
                minimumVersion: (dictionary["MinimumVersion"] as? String)?.trimmed,
                requireNotarized: boolean(dictionary["RequireNotarized"], default: true),
                allowScripts: boolean(dictionary["AllowScripts"], default: false),
                allowAnyIdentifier: allowAnyIdentifier,
                allowedPayloadPrefixes: dictionary["AllowedPayloadPrefixes"].map(stringList),
                allowUnrestrictedPayload: boolean(dictionary["AllowUnrestrictedPayload"], default: false)
            ),
            nil
        )
    }

    private static func stringList(_ value: Any?) -> [String] {
        if let single = value as? String {
            let trimmed = single.trimmed
            return trimmed.isEmpty ? [] : [trimmed]
        }

        if let many = value as? [String] {
            return many.map(\.trimmed).filter { !$0.isEmpty }
        }

        return []
    }

    private static func boolean(_ value: Any?, default defaultValue: Bool) -> Bool {
        (value as? Bool) ?? (value as? NSNumber)?.boolValue ?? defaultValue
    }
}

// MARK: - Facts

/// What the helper found in the installer it staged, before any policy is applied.
public struct InstallerFacts: Codable, Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case package
        case diskImage
    }

    public var kind: Kind
    public var fileName: String
    public var sha256: String

    /// The Team ID from the signing certificate's organisational unit.
    public var teamID: String?

    /// The leaf certificate's common name, for display: "Developer ID Installer: Google, Inc. (EQHXZ8M8AV)".
    public var authority: String?

    /// The SHA-256 of the signing certificate, when one could be read.
    public var leafCertificateSHA256: String?

    /// Whether the signature is present and chains to a certificate the system trusts.
    public var signatureTrusted: Bool

    /// Whether Gatekeeper reports the installer as notarized.
    public var notarized: Bool

    /// Package identifiers for a `.pkg`, or the app's bundle identifier for a `.dmg`.
    public var identifiers: [String]

    public var displayName: String?
    public var version: String?

    /// Whether any component of a package carries pre/postinstall scripts.
    public var hasScripts: Bool

    /// What kind of scripts were found, for the sheet and the log.
    public var scriptSummary: String?

    /// The most destinations described to the client, purely so the window has something readable.
    ///
    /// Separate from the limit `PackageInspector` enforces, and applied only after the policy has
    /// seen every one of them: a shortened list is a display convenience, never the thing a decision
    /// was made from.
    public static let displayedPayloadRoots = 12

    /// The places this installer writes, shortened to the shallowest path that contains each one.
    ///
    /// Derived by truncating every file and symlink in the package's bill of materials, so checking
    /// these covers everything underneath them. For a disk image it is simply where the application
    /// lands.
    public var payloadRoots: [String]

    /// Whether a distribution package pulls a component from a URL at install time.
    ///
    /// Always disqualifying, and not configurable: those bytes arrive after everything here has run, so
    /// nothing about them was ever checked.
    public var hasRemoteReferences: Bool

    /// Decoded field by field, with a default for everything the sender might not have sent.
    ///
    /// The app and the helper are deployed separately — with `SkipHelperInstall` the helper arrives
    /// from an MDM on its own schedule — so at any moment one of them may be a version behind. A
    /// synthesised decoder makes every added field a breaking change across that gap, and the failure
    /// surfaces to the user as "The data couldn't be read because it is missing", which tells nobody
    /// anything. Every default here is the cautious reading: absent never means more permissive.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        kind = try container.decode(Kind.self, forKey: .kind)
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName) ?? ""
        sha256 = try container.decodeIfPresent(String.self, forKey: .sha256) ?? ""
        teamID = try container.decodeIfPresent(String.self, forKey: .teamID)
        authority = try container.decodeIfPresent(String.self, forKey: .authority)
        leafCertificateSHA256 = try container.decodeIfPresent(String.self, forKey: .leafCertificateSHA256)
        signatureTrusted =
            try container.decodeIfPresent(Bool.self, forKey: .signatureTrusted) ?? false
        notarized = try container.decodeIfPresent(Bool.self, forKey: .notarized) ?? false
        identifiers = try container.decodeIfPresent([String].self, forKey: .identifiers) ?? []
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        version = try container.decodeIfPresent(String.self, forKey: .version)
        hasScripts = try container.decodeIfPresent(Bool.self, forKey: .hasScripts) ?? false
        scriptSummary = try container.decodeIfPresent(String.self, forKey: .scriptSummary)
        hasRemoteReferences =
            try container.decodeIfPresent(Bool.self, forKey: .hasRemoteReferences) ?? false
        payloadRoots = try container.decodeIfPresent([String].self, forKey: .payloadRoots) ?? []
    }

    public init(
        kind: Kind,
        fileName: String,
        sha256: String,
        teamID: String? = nil,
        authority: String? = nil,
        leafCertificateSHA256: String? = nil,
        signatureTrusted: Bool = false,
        notarized: Bool = false,
        identifiers: [String] = [],
        displayName: String? = nil,
        version: String? = nil,
        hasScripts: Bool = false,
        scriptSummary: String? = nil,
        hasRemoteReferences: Bool = false,
        payloadRoots: [String] = []
    ) {
        self.kind = kind
        self.fileName = fileName
        self.sha256 = sha256
        self.teamID = teamID
        self.authority = authority
        self.leafCertificateSHA256 = leafCertificateSHA256
        self.signatureTrusted = signatureTrusted
        self.notarized = notarized
        self.identifiers = identifiers
        self.displayName = displayName
        self.version = version
        self.hasScripts = hasScripts
        self.scriptSummary = scriptSummary
        self.hasRemoteReferences = hasRemoteReferences
        self.payloadRoots = payloadRoots
    }
}

public extension InstallerFacts {

    /// A copy safe to hand to the client, with the destination list shortened for the window.
    ///
    /// Called only once the policy has run against the full set.
    func shortenedForDisplay() -> InstallerFacts {
        guard payloadRoots.count > InstallerFacts.displayedPayloadRoots else { return self }

        var copy = self
        let shown = payloadRoots.prefix(InstallerFacts.displayedPayloadRoots)
        copy.payloadRoots = shown + ["and \(payloadRoots.count - shown.count) more"]

        return copy
    }
}

// MARK: - Assessment

/// What the helper decided about a staged installer, and what the app may do about it.
///
/// Crosses the connection as JSON so the app never has to parse an installer or read the allowlist to
/// draw its sheet. The app's own view of policy decides nothing; this is the decision.
public struct InstallerAssessment: Codable, Sendable, Equatable {

    /// What the app should offer when the installer is not allowed.
    public enum Fallback: String, Codable, Sendable {
        /// Hand the file to Installer.app or Finder, exactly as a double-click would behave without us.
        case installer
        /// Offer the existing time-limited elevation flow instead.
        case elevate
        /// Offer nothing.
        case none
    }

    /// Names the staged copy this assessment was made from. Present only when the install may proceed.
    public var token: String?

    public var facts: InstallerFacts
    public var isAllowed: Bool

    /// The `Name` of the allowlist entry that matched.
    public var matchedEntry: String?
    public var matchMode: InstallerMatchMode?

    /// Why it did not match, in the admin's terms, for the sheet and the log.
    public var rejectionReasons: [String]

    public var fallback: Fallback

    /// Whether the app must authenticate the user before asking for the install.
    public var requiresAuthentication: Bool

    /// As with `InstallerFacts`, tolerant of a sender that is a version behind. An assessment missing
    /// its verdict decodes as refused, and one missing its authentication setting as requiring it.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        token = try container.decodeIfPresent(String.self, forKey: .token)
        facts = try container.decode(InstallerFacts.self, forKey: .facts)
        isAllowed = try container.decodeIfPresent(Bool.self, forKey: .isAllowed) ?? false
        matchedEntry = try container.decodeIfPresent(String.self, forKey: .matchedEntry)
        matchMode = try container.decodeIfPresent(InstallerMatchMode.self, forKey: .matchMode)
        rejectionReasons =
            try container.decodeIfPresent([String].self, forKey: .rejectionReasons) ?? []
        fallback = try container.decodeIfPresent(Fallback.self, forKey: .fallback) ?? .installer
        requiresAuthentication =
            try container.decodeIfPresent(Bool.self, forKey: .requiresAuthentication) ?? true
    }

    public init(
        token: String?,
        facts: InstallerFacts,
        isAllowed: Bool,
        matchedEntry: String?,
        matchMode: InstallerMatchMode?,
        rejectionReasons: [String],
        fallback: Fallback,
        requiresAuthentication: Bool
    ) {
        self.token = token
        self.facts = facts
        self.isAllowed = isAllowed
        self.matchedEntry = matchedEntry
        self.matchMode = matchMode
        self.rejectionReasons = rejectionReasons
        self.fallback = fallback
        self.requiresAuthentication = requiresAuthentication
    }
}

// MARK: - JSON

extension InstallerAssessment {

    public func jsonString() throws -> String {
        let data = try JSONEncoder().encode(self)

        guard let json = String(data: data, encoding: .utf8) else {
            throw SupportCompanionErrors.invalidStringConversion
        }

        return json
    }

    public static func make(fromJSON json: String) throws -> InstallerAssessment {
        guard let data = json.data(using: .utf8) else {
            throw SupportCompanionErrors.invalidStringConversion
        }

        return try JSONDecoder().decode(InstallerAssessment.self, from: data)
    }
}

// MARK: - Matching

public enum InstallerPolicy {

    /// Decide whether the facts satisfy any entry in the allowlist.
    ///
    /// Every entry is tried, and the one that got furthest supplies the reasons when none of them
    /// matched — "Chrome is allowed, but only from version 141" is worth saying, while "no entry named
    /// this" is not, when an entry plainly meant this app.
    /// - Returns: the entry that allowed it, the reasons safe to show the person at the Mac, and the
    ///   fuller reasons for the root-owned log.
    ///
    /// The two sets of reasons differ on purpose. What an administrator allows elsewhere is their
    /// business, not something to list in a window because somebody opened the wrong installer, so the
    /// user's copy never names another entry or what it expected. The log is root-owned and is where
    /// the detail belongs.
    public static func evaluate(
        _ facts: InstallerFacts,
        against allowlist: [AllowedInstaller]
    ) -> (entry: AllowedInstaller?, reasons: [String], logReasons: [String]) {

        guard !allowlist.isEmpty else {
            return (nil, [unlisted], ["No applications have been allowed by an administrator"])
        }

        var closest: (entry: AllowedInstaller, reasons: [String])?

        for entry in allowlist {
            let reasons = disqualifications(of: facts, for: entry)

            if reasons.isEmpty {
                return (entry, [], [])
            }

            // Only entries that are recognisably about *this* installer may explain it. Without this,
            // the single entry an administrator has configured is always the "closest" one, and a user
            // installing something unrelated is told their package is the wrong version of Firefox.
            guard isAbout(facts, entry: entry) else { continue }

            // Fewer objections means the entry was more nearly about this installer. Ties keep the
            // first, so the order in the profile decides what the user is told.
            if closest == nil || reasons.count < closest!.reasons.count {
                closest = (entry, reasons)
            }
        }

        guard let closest else {
            return (nil, [unlisted], [unlistedReason(for: facts)])
        }

        // The entry is about this installer, so its objections describe the file in front of the user
        // and can be shown as they are. Only the entry's name is dropped, which tells them nothing
        // they can act on and names a rule that is not theirs to see.
        return (
            nil,
            closest.reasons.map { $0.prefix(1).capitalized + $0.dropFirst() },
            closest.reasons.map { "\(closest.entry.name): \($0)" }
        )
    }

    /// What the user is told when nothing on the list was written for this installer.
    public static let unlisted =
        "This installer is not on your organisation's list of approved software"

    /// Whether an entry is plainly meant for this installer, whatever else it objects to.
    ///
    /// The test is identity alone — the digest in strict mode, an identifier in signature mode. An
    /// entry that matches neither is about some other application, and its objections say nothing
    /// useful about this one.
    private static func isAbout(_ facts: InstallerFacts, entry: AllowedInstaller) -> Bool {
        switch entry.mode {
        case .strict:
            return facts.sha256.caseInsensitiveCompare(entry.sha256 ?? "") == .orderedSame

        case .signature:
            if entry.allowAnyIdentifier {
                return entry.teamID != nil && entry.teamID == facts.teamID
            }

            let accepted =
                facts.kind == .package ? entry.packageIdentifiers : entry.bundleIdentifiers
            return accepted.contains(where: facts.identifiers.contains)
        }
    }

    /// What to say about an installer no entry was written for.
    ///
    /// Names what the installer says it is, because that is what has to go into a profile for it to be
    /// allowed — the person reading this is either forwarding it to an administrator or is one.
    private static func unlistedReason(for facts: InstallerFacts) -> String {
        var identity: [String] = []

        if let first = facts.identifiers.first {
            identity.append(first)
        }

        if let team = facts.teamID {
            identity.append("team \(team)")
        }

        guard !identity.isEmpty else {
            return "No entry on your organisation's list covers this installer"
        }

        return
            "No entry on your organisation's list covers this installer (\(identity.joined(separator: ", ")))"
    }

    /// Everything about `facts` that stops `entry` from allowing it. Empty means allowed.
    private static func disqualifications(of facts: InstallerFacts, for entry: AllowedInstaller)
        -> [String]
    {
        var reasons: [String] = []

        switch entry.mode {
        case .strict:
            if facts.sha256.caseInsensitiveCompare(entry.sha256 ?? "") != .orderedSame {
                reasons.append("this file's SHA-256 is not the one allowed")
            }

        case .signature:
            if !facts.signatureTrusted {
                reasons.append("it is not signed by a certificate the system trusts")
            }

            if let required = entry.teamID {
                if let found = facts.teamID {
                    if found != required {
                        reasons.append("it is signed by team \(found), not \(required)")
                    }
                } else {
                    reasons.append("no Team ID could be read from its signature")
                }
            }

            if !entry.allowAnyIdentifier {
                let accepted =
                    facts.kind == .package ? entry.packageIdentifiers : entry.bundleIdentifiers

                if accepted.isEmpty {
                    reasons.append(
                        facts.kind == .package
                            ? "no PackageIdentifier is configured for this kind of installer"
                            : "no BundleIdentifier is configured for this kind of installer"
                    )
                } else if facts.identifiers.isEmpty {
                    reasons.append("no identifier could be read from it")
                } else {
                    // Every identifier, not merely one of them. A distribution package installs all of
                    // its components, so accepting it because one component was named would let the
                    // others in unexamined — which is how an approved application arrives with a
                    // LaunchDaemon nobody asked about.
                    let uncovered = facts.identifiers.filter { !accepted.contains($0) }

                    if !uncovered.isEmpty {
                        reasons.append(
                            "it also installs \(uncovered.joined(separator: ", ")), which this entry does not allow"
                        )
                    }
                }
            }
        }

        // Applies in both modes. A digest of the file pins these exact bytes; this pins who signed
        // them, which keeps holding as the vendor ships new versions.
        if let required = entry.leafCertificateSHA256 {
            if let found = facts.leafCertificateSHA256 {
                if found.caseInsensitiveCompare(required) != .orderedSame {
                    reasons.append("it is signed by a different certificate than the one allowed")
                }
            } else {
                reasons.append("no signing certificate could be read from it")
            }
        }

        // Applies in both modes: a digest pins the bytes, but the administrator still said notarized.
        if entry.requireNotarized && !facts.notarized {
            reasons.append("it is not notarized")
        }

        if facts.kind == .package && facts.hasScripts && !entry.allowScripts {
            let what = facts.scriptSummary ?? "install scripts that run as root"
            reasons.append("it carries \(what), which this entry does not allow")
        }

        if facts.hasRemoteReferences {
            reasons.append(
                "it downloads further packages while installing, which cannot be checked in advance"
            )
        }

        // Applies in both modes: a digest pins which bytes arrive, not where they end up.
        if !entry.allowUnrestrictedPayload {
            if let prefixes = entry.allowedPayloadPrefixes, !prefixes.isEmpty {
                let outside = facts.payloadRoots.filter { root in
                    !prefixes.contains { isPath(root, under: $0) }
                }

                if !outside.isEmpty {
                    reasons.append(
                        "it writes to \(outside.prefix(4).joined(separator: ", ")), which this entry does not allow"
                    )
                }
            } else {
                // Nothing configured means the usual places an application goes — not anywhere at
                // all. Checked in both directions because `payloadRoots` are truncated towards the
                // root, so a reported root can sit *above* a protected prefix as easily as inside it.
                let blocked = facts.payloadRoots.filter { root in
                    protectedPrefixes.contains { isPath(root, under: $0) || isPath($0, under: root) }
                }

                if !blocked.isEmpty {
                    reasons.append(
                        "it writes to \(blocked.prefix(4).joined(separator: ", ")), which needs AllowedPayloadPrefixes to permit it"
                    )
                }
            }
        }

        if let minimum = entry.minimumVersion {
            if let version = facts.version {
                if isVersion(version, olderThan: minimum) {
                    reasons.append(
                        "version \(version) is older than the allowed minimum \(minimum)")
                }
            } else {
                reasons.append("no version could be read, and a minimum of \(minimum) is required")
            }
        }

        return reasons
    }

    /// The few places an installer may not write unless an administrator names them explicitly.
    ///
    /// Deliberately short, and not a general hardening list. Once an entry has said "this vendor,
    /// this identifier, notarized", a package that installs a launch daemon or a command in
    /// `/usr/local/bin` is not misbehaving — that is what Docker, a VPN client and most developer
    /// tooling *are*. Refusing those by default would mean the feature did not work for a large part
    /// of real software, and the answer administrators would reach for is `AllowUnrestrictedPayload`
    /// on every entry, which is worse than never having checked.
    ///
    /// What is left is a different kind of thing: not "software doing something privileged" but
    /// "software taking over the thing that decides what software may do". None of these is a
    /// destination an application installer has any reason to write to, and each one turns a single
    /// install into lasting control of the mechanism meant to be governing it.
    ///
    /// An administrator who wants the stricter posture still has it, by naming prefixes on the entry
    /// — opting in to tight, rather than opting out of unusable.
    public static let protectedPrefixes = [
        // Deciding what may be installed, and who may hold administrator rights.
        "/Library/Managed Preferences",
        "/Library/Preferences",
        "/var/db/com.github.macadmins.SupportCompanion",
        "/private/var/db/com.github.macadmins.SupportCompanion",

        // Becoming something privileged, or standing in front of one.
        "/Library/PrivilegedHelperTools",
        "/Library/Security",
        "/Library/ScriptingAdditions",

        // Local accounts: writing here is how an administrator account appears out of nothing.
        "/var/db/dslocal",
        "/private/var/db/dslocal",

        // Root, directly.
        "/etc/sudoers",
        "/etc/sudoers.d",
        "/etc/pam.d",
        "/etc/ssh",
        "/private/etc/sudoers",
        "/private/etc/sudoers.d",
        "/private/etc/pam.d",
        "/private/etc/ssh",
        "/var/root",
        "/private/var/root",
    ]

    /// Whether `path` is the same as `prefix` or sits inside it.
    ///
    /// Compared at path-component boundaries, so `/Applications/Firefox.app` is not treated as being
    /// inside `/Applications/Fire`.
    static func isPath(_ path: String, under prefix: String) -> Bool {
        let path = (path as NSString).standardizingPath
        let prefix = (prefix as NSString).standardizingPath

        if path == prefix { return true }

        return path.hasPrefix(prefix.hasSuffix("/") ? prefix : prefix + "/")
    }

    /// Compare two dotted versions numerically, so 10.2 is newer than 10.10 is not mistaken for true.
    static func isVersion(_ version: String, olderThan minimum: String) -> Bool {
        let left = components(of: version)
        let right = components(of: minimum)

        for index in 0..<max(left.count, right.count) {
            let a = index < left.count ? left[index] : 0
            let b = index < right.count ? right[index] : 0

            if a != b { return a < b }
        }

        return false
    }

    private static func components(of version: String) -> [Int] {
        version
            .split(whereSeparator: { !$0.isNumber })
            .map { Int($0) ?? 0 }
    }
}

// MARK: - Convenience

// Kept file-private: this file is compiled into both the app and the helper, and a name this general
// on String would be waiting to collide with one of them.
extension String {
    fileprivate var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

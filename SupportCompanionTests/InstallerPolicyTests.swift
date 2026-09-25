//
//  InstallerPolicyTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@Suite("Installer allowlist")
struct InstallerPolicyTests {

    // MARK: Fixtures

    private func entry(_ dictionary: [String: Any]) -> AllowedInstaller {
        let (entry, problem) = AllowedInstaller.make(from: dictionary)
        #expect(problem == nil)
        return try! #require(entry)
    }

    private var chrome: AllowedInstaller {
        entry([
            "Name": "Google Chrome",
            "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome",
            "MinimumVersion": "141.0",
        ])
    }

    private func facts(
        kind: InstallerFacts.Kind = .package,
        team: String? = "EQHXZ8M8AV",
        identifiers: [String] = ["com.google.Chrome"],
        version: String? = "141.0.1",
        trusted: Bool = true,
        notarized: Bool = true,
        scripts: Bool = false,
        remote: Bool = false,
        sha256: String = String(repeating: "a", count: 64),
        leafCertificateSHA256: String? = String(repeating: "c", count: 64),
        payloadRoots: [String] = ["/Applications/Google Chrome.app"]
    ) -> InstallerFacts {
        InstallerFacts(
            kind: kind,
            fileName: "installer.pkg",
            sha256: sha256,
            teamID: team,
            leafCertificateSHA256: leafCertificateSHA256,
            signatureTrusted: trusted,
            notarized: notarized,
            identifiers: identifiers,
            version: version,
            hasScripts: scripts,
            hasRemoteReferences: remote,
            payloadRoots: payloadRoots
        )
    }

    private func isAllowed(_ facts: InstallerFacts, _ allowlist: [AllowedInstaller]) -> Bool {
        InstallerPolicy.evaluate(facts, against: allowlist).entry != nil
    }

    // MARK: Signature matching

    @Test("Allows a package whose team, identifier and version all match")
    func matches() {
        #expect(isAllowed(facts(), [chrome]))
    }

    @Test("Refuses a package signed by another team")
    func wrongTeam() {
        #expect(!isAllowed(facts(team: "XXXXXXXXXX"), [chrome]))
    }

    @Test("Refuses a package the right team signed but that identifies as something else")
    func wrongIdentifier() {
        #expect(!isAllowed(facts(identifiers: ["com.example.Other"]), [chrome]))
    }

    @Test("Refuses a package whose signature does not chain to a trusted certificate")
    func untrusted() {
        #expect(!isAllowed(facts(trusted: false), [chrome]))
    }

    @Test("Refuses a package that is not notarized, unless the entry says otherwise")
    func notarization() {
        #expect(!isAllowed(facts(notarized: false), [chrome]))

        let relaxed = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome", "RequireNotarized": false,
        ])
        #expect(isAllowed(facts(notarized: false), [relaxed]))
    }

    @Test("Refuses a package carrying install scripts, unless the entry allows them")
    func scripts() {
        #expect(!isAllowed(facts(scripts: true), [chrome]))

        let relaxed = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome", "AllowScripts": true,
        ])
        #expect(isAllowed(facts(scripts: true), [relaxed]))
    }

    @Test("Refuses a package that downloads more packages while installing, whatever the entry says")
    func remoteReferences() {
        let permissive = entry([
            "Name": "Anything", "TeamID": "EQHXZ8M8AV",
            "AllowAnyIdentifier": true, "AllowScripts": true, "RequireNotarized": false,
        ])
        #expect(!isAllowed(facts(remote: true), [permissive]))
    }

    @Test("Refuses a version below the entry's minimum")
    func versionFloor() {
        #expect(!isAllowed(facts(version: "140.9"), [chrome]))
        #expect(!isAllowed(facts(version: nil), [chrome]))
    }

    @Test("Refuses everything when nothing has been allowed")
    func emptyAllowlist() {
        #expect(!isAllowed(facts(), []))
    }

    @Test("Matches a disk image on its bundle identifier rather than a package identifier")
    func diskImageIdentifier() {
        let app = entry([
            "Name": "Demo", "TeamID": "EQHXZ8M8AV", "BundleIdentifier": "com.example.Demo",
        ])

        #expect(isAllowed(facts(kind: .diskImage, identifiers: ["com.example.Demo"], version: nil), [app]))
        // The same entry must not let the package through: the keys are per kind on purpose.
        #expect(!isAllowed(facts(identifiers: ["com.example.Demo"], version: nil), [app]))
    }

    // MARK: Components

    @Test("Refuses a package that installs a component the entry does not name")
    func uncoveredComponent() {
        let appOnly = entry([
            "Name": "Alpha", "TeamID": "EQHXZ8M8AV", "PackageIdentifier": "com.example.alpha",
            "RequireNotarized": false,
        ])

        let twoComponents = facts(identifiers: ["com.example.alpha", "com.example.beta"], version: nil, notarized: false)
        #expect(!isAllowed(twoComponents, [appOnly]))

        let both = entry([
            "Name": "Alpha", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": ["com.example.alpha", "com.example.beta"],
            "RequireNotarized": false,
        ])
        #expect(isAllowed(twoComponents, [both]))
    }

    @Test("Names the component it objected to")
    func uncoveredComponentIsNamed() {
        let appOnly = entry([
            "Name": "Alpha", "TeamID": "EQHXZ8M8AV", "PackageIdentifier": "com.example.alpha",
            "RequireNotarized": false,
        ])

        let decision = InstallerPolicy.evaluate(
            facts(identifiers: ["com.example.alpha", "com.example.beta"], version: nil, notarized: false),
            against: [appOnly]
        )

        #expect(decision.entry == nil)
        #expect(decision.reasons.contains { $0.contains("com.example.beta") })
    }

    // MARK: Payload prefixes

    @Test("Lets ordinary software install with nothing configured")
    func ordinarySoftwareNeedsNoPayloadConfiguration() {
        // These are what real installers do. Refusing them by default would make the feature
        // unusable for most software and push administrators towards AllowUnrestrictedPayload.
        for root in [
            "/Applications/Google Chrome.app",
            "/Library/Application Support/Example",
            "/Library/LaunchDaemons/com.vendor.plist",
            "/Library/LaunchAgents/com.vendor.plist",
            "/usr/local/bin/tool",
            "/usr/local/lib/libtool.dylib",
            "/Library/Extensions/Vendor.kext",
            "/Library/QuickLook/Vendor.qlgenerator",
            "/etc/paths.d/vendor",
        ] {
            #expect(isAllowed(facts(payloadRoots: ["/Applications/Example.app", root]), [chrome]), "\(root) should install without configuration")
        }
    }

    @Test("Still refuses the places that would take over the control itself")
    func protectsTheControlItself() {
        for root in [
            "/Library/PrivilegedHelperTools/com.example.helper",
            "/Library/Security/SecurityAgentPlugins/x.bundle",
            "/Library/ScriptingAdditions/Example.osax",
            "/etc/sudoers.d/example",
            "/etc/pam.d/authorization",
            "/private/etc/ssh/sshd_config",
            "/var/db/dslocal/nodes/Default/users/admin.plist",
            "/var/root/.ssh/authorized_keys",
        ] {
            #expect(!isAllowed(facts(payloadRoots: ["/Applications/Example.app", root]), [chrome]), "\(root) should be protected")
        }
    }

    @Test("Protects the preferences that hold the allowlist itself")
    func protectsItsOwnPolicy() {
        // A package writing these rewrites the list that authorised it, plus EnforceAdminAllowlist
        // and PermanentAdmins — one install becoming lasting control of the whole feature.
        #expect(!isAllowed(facts(payloadRoots: ["/Library/Preferences/com.github.macadmins.SupportCompanion.plist"]), [chrome]))
        #expect(!isAllowed(facts(payloadRoots: ["/Library/Managed Preferences/com.github.macadmins.SupportCompanion.plist"]), [chrome]))
    }

    @Test("Catches a payload root sitting above a protected prefix, not only inside one")
    func denyListIsBidirectional() {
        // payloadRoots truncate towards the root, so a root can be an ancestor of a protected path.
        // "/Library" contains /Library/Preferences, "/etc" contains /etc/sudoers.d.
        #expect(!isAllowed(facts(payloadRoots: ["/Library"]), [chrome]))
        #expect(!isAllowed(facts(payloadRoots: ["/etc"]), [chrome]))

        // ...while a prefix containing nothing protected is fine, which is the point of the change:
        // /usr/local is ordinary software territory again.
        #expect(isAllowed(facts(payloadRoots: ["/usr/local"]), [chrome]))
    }

    @Test("Checks every destination, however many there are")
    func everyRootIsChecked() {
        // A package with more destinations than the window shows, where the dangerous one sorts last.
        var roots = (1...30).map { "/Applications/a\(String(format: "%02d", $0)).app" }
        roots.append("/Library/PrivilegedHelperTools/com.example.helper")

        #expect(!isAllowed(facts(payloadRoots: roots), [chrome]))

        let decision = InstallerPolicy.evaluate(facts(payloadRoots: roots), against: [chrome])
        #expect(decision.reasons.contains { $0.contains("PrivilegedHelperTools") })
    }

    @Test("Shortening for the window happens after the decision, not before it")
    func shorteningIsDisplayOnly() {
        let roots = (1...30).map { "/Applications/a\($0).app" }
        let full = facts(payloadRoots: roots)

        #expect(full.payloadRoots.count == 30)

        let shown = full.shortenedForDisplay()
        #expect(shown.payloadRoots.count == InstallerFacts.displayedPayloadRoots + 1)
        #expect(shown.payloadRoots.last?.contains("more") == true)

        // The shortened copy is for the sheet; the original is what was judged.
        #expect(full.payloadRoots.count == 30)
    }

    @Test("Naming prefixes explicitly replaces the protection rather than adding to it")
    func explicitPrefixesOverrideTheDenyList() {
        let daemon = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome",
            "AllowedPayloadPrefixes": ["/Applications", "/Library/LaunchDaemons"],
        ])

        #expect(isAllowed(facts(payloadRoots: ["/Applications/Google Chrome.app", "/Library/LaunchDaemons/x.plist"]), [daemon]))
    }

    @Test("Unrestricted needs its own key, not a prefix of /")
    func unrestrictedIsExplicit() {
        let unrestricted = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome",
            "AllowUnrestrictedPayload": true,
        ])

        #expect(isAllowed(facts(payloadRoots: ["/etc/sudoers.d/x", "/var/root/x"]), [unrestricted]))
    }

    @Test("Refuses a package that writes outside the prefixes it was given")
    func payloadPrefixes() {
        let confined = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome",
            "AllowedPayloadPrefixes": ["/Applications"],
        ])

        #expect(isAllowed(facts(payloadRoots: ["/Applications/Google Chrome.app"]), [confined]))
        #expect(!isAllowed(
            facts(payloadRoots: ["/Applications/Google Chrome.app", "/Library/LaunchDaemons/x.plist"]),
            [confined]
        ))
    }

    @Test("Matches prefixes at path boundaries, not as plain text")
    func prefixBoundaries() {
        #expect(InstallerPolicy.isPath("/Applications/Firefox.app", under: "/Applications"))
        #expect(InstallerPolicy.isPath("/Applications/Firefox.app", under: "/Applications/Firefox.app"))
        #expect(!InstallerPolicy.isPath("/Applications/Firefox.app", under: "/Applications/Fire"))
        #expect(!InstallerPolicy.isPath("/Library/LaunchDaemons", under: "/Applications"))
    }

    @Test("A digest pins the bytes, not where they land")
    func strictStillChecksPayload() {
        let strict = entry([
            "Name": "In-house tool",
            "SHA256": String(repeating: "a", count: 64),
            "RequireNotarized": false,
            "AllowedPayloadPrefixes": ["/Applications"],
        ])

        #expect(!isAllowed(facts(payloadRoots: ["/Library/LaunchDaemons/x.plist"]), [strict]))
    }

    // MARK: Certificate pin

    @Test("Ignores the certificate unless an entry pins one")
    func certificateNotPinned() {
        #expect(isAllowed(facts(leafCertificateSHA256: String(repeating: "f", count: 64)), [chrome]))
        #expect(isAllowed(facts(leafCertificateSHA256: nil), [chrome]))
    }

    @Test("Refuses a different certificate when one is pinned")
    func certificatePinned() {
        let pinned = entry([
            "Name": "Google Chrome", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": "com.google.Chrome",
            "LeafCertificateSHA256": String(repeating: "C", count: 64),
        ])

        // Case and spacing are how a digest gets pasted out of pkgutil, so both are tolerated.
        #expect(isAllowed(facts(leafCertificateSHA256: String(repeating: "c", count: 64)), [pinned]))
        #expect(!isAllowed(facts(leafCertificateSHA256: String(repeating: "d", count: 64)), [pinned]))
        #expect(!isAllowed(facts(leafCertificateSHA256: nil), [pinned]))
    }

    @Test("Refuses a malformed certificate pin rather than ignoring it")
    func certificatePinMustBeADigest() {
        #expect(AllowedInstaller.make(from: [
            "Name": "X", "TeamID": "EQHXZ8M8AV", "PackageIdentifier": "com.x",
            "LeafCertificateSHA256": "not-a-digest",
        ]).entry == nil)

        // Spaces are stripped, since that is how pkgutil prints it.
        #expect(AllowedInstaller.make(from: [
            "Name": "X", "TeamID": "EQHXZ8M8AV", "PackageIdentifier": "com.x",
            "LeafCertificateSHA256": "A3 D1 49 1B 4B 09 F8 D2 4E A8 32 D3 0C B3 5A 3A C0 32 08 3F 37 8A 6A 16 95 D0 CB C1 57 74 BA 99",
        ]).entry?.leafCertificateSHA256 == "a3d1491b4b09f8d24ea832d30cb35a3ac032083f378a6a1695d0cbc15774ba99")
    }

    @Test("A pinned certificate still applies in strict mode")
    func certificatePinInStrictMode() {
        let strict = entry([
            "Name": "In-house", "SHA256": String(repeating: "a", count: 64),
            "RequireNotarized": false,
            "LeafCertificateSHA256": String(repeating: "c", count: 64),
        ])

        #expect(isAllowed(facts(), [strict]))
        #expect(!isAllowed(facts(leafCertificateSHA256: String(repeating: "d", count: 64)), [strict]))
    }

    // MARK: Strict matching

    @Test("Allows only the exact digest in strict mode")
    func strictDigest() {
        let strict = entry([
            "Name": "In-house tool",
            "SHA256": String(repeating: "a", count: 64),
            "RequireNotarized": false,
        ])

        #expect(isAllowed(facts(team: nil, identifiers: [], version: nil, trusted: false), [strict]))
        #expect(!isAllowed(facts(sha256: String(repeating: "b", count: 64)), [strict]))
    }

    @Test("A digest does not excuse the entry's other conditions")
    func strictStillChecksTheRest() {
        let strict = entry(["Name": "In-house tool", "SHA256": String(repeating: "a", count: 64)])
        #expect(!isAllowed(facts(notarized: false), [strict]))
    }

    // MARK: Entry validation

    @Test("Drops an entry that could never match")
    func invalidEntries() {
        #expect(AllowedInstaller.make(from: ["Name": "X"]).entry == nil)
        #expect(AllowedInstaller.make(from: ["TeamID": "EQHXZ8M8AV"]).entry == nil)
        #expect(AllowedInstaller.make(from: ["Name": "X", "SHA256": "tooshort"]).entry == nil)
    }

    @Test("Drops a team-only entry unless it says AllowAnyIdentifier")
    func teamWithoutIdentifier() {
        #expect(AllowedInstaller.make(from: ["Name": "X", "TeamID": "EQHXZ8M8AV"]).entry == nil)

        let vendor = entry(["Name": "X", "TeamID": "EQHXZ8M8AV", "AllowAnyIdentifier": true])
        #expect(isAllowed(facts(identifiers: ["com.anything.At.All"], version: nil), [vendor]))
        #expect(!isAllowed(facts(team: "OTHER00000", identifiers: ["com.anything.At.All"], version: nil), [vendor]))
    }

    @Test("Accepts several identifiers for one entry")
    func identifierList() {
        let either = entry([
            "Name": "X", "TeamID": "EQHXZ8M8AV",
            "PackageIdentifier": ["com.example.One", "com.example.Two"],
        ])

        #expect(isAllowed(facts(identifiers: ["com.example.Two"], version: nil), [either]))
        #expect(!isAllowed(facts(identifiers: ["com.example.Three"], version: nil), [either]))
    }

    // MARK: Versions

    @Test("Compares versions numerically rather than as text", arguments: [
        ("10.10", "10.2", false),
        ("10.2", "10.10", true),
        ("141.0.1", "141", false),
        ("141.0", "141.0", false),
        ("2", "10", true),
    ])
    func versionComparison(version: String, minimum: String, older: Bool) {
        #expect(InstallerPolicy.isVersion(version, olderThan: minimum) == older)
    }

    // MARK: Reasons

    @Test("Explains the refusal using the entry that came closest")
    func reasons() {
        let unrelated = entry(["Name": "Firefox", "TeamID": "43AQ936H96", "PackageIdentifier": "org.mozilla.firefox"])
        let decision = InstallerPolicy.evaluate(facts(version: "140.0"), against: [unrelated, chrome])

        #expect(decision.entry == nil)
        #expect(decision.reasons.count == 1)

        // What the user sees never names the entry; the log keeps the full attribution.
        #expect(!decision.reasons[0].contains("Google Chrome"))
        #expect(decision.reasons[0].contains("141.0"))
        #expect(decision.logReasons[0].hasPrefix("Google Chrome:"))
    }

    @Test("Tells the user nothing about the rest of the list when no entry was written for it")
    func unlistedSaysNothingAboutOtherEntries() {
        let unrelated = entry([
            "Name": "Firefox", "TeamID": "43AQ936H96", "BundleIdentifier": "org.mozilla.firefox",
        ])

        let decision = InstallerPolicy.evaluate(
            facts(identifiers: ["com.github.autopkg.autopkg"], version: nil, notarized: false),
            against: [unrelated]
        )

        #expect(decision.entry == nil)
        #expect(decision.reasons == [InstallerPolicy.unlisted])
        #expect(!decision.reasons[0].contains("Firefox"))
        #expect(!decision.reasons[0].contains("mozilla"))
    }

    // MARK: Transport

    @Test("An assessment survives the trip over the connection as JSON")
    func jsonRoundTrip() throws {
        let assessment = InstallerAssessment(
            token: UUID().uuidString,
            facts: facts(),
            isAllowed: true,
            matchedEntry: "Google Chrome",
            matchMode: .signature,
            rejectionReasons: [],
            fallback: .elevate,
            requiresAuthentication: true
        )

        #expect(try InstallerAssessment.make(fromJSON: assessment.jsonString()) == assessment)
    }

    @Test("An unknown fallback falls back to handing the file to Installer.app")
    func fallbackParsing() {
        #expect(InstallerAssessment.Fallback(rawValue: "elevate") == .elevate)
        #expect(InstallerAssessment.Fallback(rawValue: "nonsense") == nil)
    }
}

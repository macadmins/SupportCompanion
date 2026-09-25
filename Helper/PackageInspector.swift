//
//  PackageInspector.swift
//  com.github.macadmins.SupportCompanion.helper
//

import Foundation

/// Reads what an installer package claims to be, from a copy only root can write.
///
/// Every function here takes a path inside the staging directory, never the path the user chose. The
/// order matters: the bytes are copied first, and only the copy is ever inspected or installed, so
/// there is no window in which the file that was judged and the file that gets installed can differ.
enum PackageInspector {

    // MARK: Signing

    /// What `spctl` and `pkgutil` between them say about a package's signature.
    struct Signature {
        var trusted = false
        var notarized = false
        var teamID: String?
        var authority: String?
        var leafCertificateSHA256: String?
    }

    /// Ask Gatekeeper to assess the package as an installation.
    ///
    /// This is `SecAssessmentCreate` with `kSecAssessmentOperationTypeInstall` behind a command line,
    /// which reports the authority and the source in one place rather than a nested dictionary.
    ///
    /// It answers to the machine's Gatekeeper configuration, so on a Mac where assessments have been
    /// turned off it approves everything. That is why the certificate chain is checked separately below
    /// and why `notarized` is reported as false when assessments are disabled: a policy that says
    /// "notarized only" must not quietly become "anything" because somebody ran `spctl --global-disable`.
    private static func gatekeeperAssessment(of path: String) async -> (accepted: Bool, source: String?, origin: String?) {
        guard await assessmentsAreEnabled() else {
            Logger.shared.logError("Gatekeeper assessments are disabled on this Mac; treating \(path) as unassessed")
            return (false, nil, nil)
        }

        let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/spctl"),
            arguments: ["--assess", "--type", "install", "-vv", path]
        )

        guard let result else { return (false, nil, nil) }

        // spctl writes its detail to standard error, including when it accepts.
        let output = (String(data: result.output, encoding: .utf8) ?? "")
            + (String(data: result.error, encoding: .utf8) ?? "")

        return (
            result.status == 0,
            value(ofKey: "source", in: output),
            value(ofKey: "origin", in: output)
        )
    }

    private static func assessmentsAreEnabled() async -> Bool {
        let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/spctl"),
            arguments: ["--status"]
        )

        guard let result else { return false }

        let output = (String(data: result.output, encoding: .utf8) ?? "")
            + (String(data: result.error, encoding: .utf8) ?? "")

        return output.contains("assessments enabled")
    }

    private static func value(ofKey key: String, in output: String) -> String? {
        output
            .split(separator: "\n")
            .first { $0.hasPrefix("\(key)=") }
            .map { String($0.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces) }
    }

    /// The `pkgutil --check-signature` statuses that count as a real, trusted signature.
    ///
    /// Listing what is accepted rather than what is rejected means a status this was never taught
    /// about fails closed. The first is what an ordinary Developer ID installer package reports and is
    /// the common case; note that it is specifically *for distribution*, since the same sentence ends
    /// "(Development)" for a development certificate, which is not something to install from.
    private static let acceptedStatuses = [
        "signed by a developer certificate issued by Apple for distribution",
        "signed by a certificate trusted by",
        "signed Apple Software",
    ]

    /// Check the package's own signature independently of Gatekeeper, and read the signing team.
    ///
    /// The Team ID comes from the leaf certificate's common name, which `pkgutil` prints as
    /// `Developer ID Installer: Example Ltd. (ABCDE12345)`. Matching on the parenthesised team rather
    /// than the name is deliberate: the name is chosen by the developer and is not unique.
    private static func certificateChain(of path: String) async -> (trusted: Bool, teamID: String?, authority: String?, leaf: String?) {
        let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/pkgutil"),
            arguments: ["--check-signature", path]
        )

        guard let result, result.status == 0 else { return (false, nil, nil, nil) }

        let output = String(data: result.output, encoding: .utf8) ?? ""

        let status = output
            .split(separator: "\n")
            .first { $0.contains("Status:") }
            .map { String($0).trimmingCharacters(in: .whitespaces) } ?? ""

        let trusted = acceptedStatuses.contains { status.contains($0) }

        guard trusted else {
            Logger.shared.logError("Package at \(path) is not trusted: \(status)")
            return (false, nil, nil, nil)
        }

        // The leaf is the first numbered entry in the chain.
        let leaf = output
            .split(separator: "\n")
            .first { $0.trimmingCharacters(in: .whitespaces).hasPrefix("1. ") }
            .map { String($0).trimmingCharacters(in: .whitespaces).dropFirst(3) }
            .map(String.init)

        let fingerprint = leafFingerprint(in: output)

        guard let leaf else { return (true, nil, nil, fingerprint) }

        let teamID = leaf.range(of: #"\(([A-Z0-9]{10})\)$"#, options: .regularExpression)
            .map { String(leaf[$0].dropFirst().dropLast()) }

        return (true, teamID, leaf, fingerprint)
    }

    /// The SHA-256 of the leaf certificate, from the fingerprint `pkgutil` prints beneath it.
    ///
    /// Printed as space-separated hex across however many lines it takes, under the first numbered
    /// entry in the chain — which is the leaf. Collection stops at the first line that is not hex,
    /// which is the rule separating one certificate from the next, so a fingerprint from further down
    /// the chain can never be mistaken for the leaf's.
    static func leafFingerprint(in output: String) -> String? {
        var insideLeaf = false
        var collecting = false
        var digest = ""

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("1. ") {
                insideLeaf = true
                continue
            }

            guard insideLeaf else { continue }

            // Any other numbered entry ends the leaf's section.
            if trimmed.range(of: #"^\d+\. "#, options: .regularExpression) != nil { break }

            if trimmed.hasPrefix("SHA256 Fingerprint:") {
                collecting = true
                continue
            }

            guard collecting else { continue }

            let hex = trimmed.replacingOccurrences(of: " ", with: "")

            guard !hex.isEmpty, hex.allSatisfy(\.isHexDigit) else { break }

            digest += hex
        }

        let normalized = digest.lowercased()

        return normalized.count == 64 ? normalized : nil
    }

    /// Whether a Gatekeeper `source=` names a notarized authority.
    static func isNotarized(source: String?) -> Bool {
        guard let source = source?.trimmingCharacters(in: .whitespaces) else { return false }
        return source.hasPrefix("Notarized")
    }

    static func signature(of path: String) async -> Signature {
        let chain = await certificateChain(of: path)
        let gatekeeper = await gatekeeperAssessment(of: path)

        return Signature(
            trusted: chain.trusted,
            // Accepted *and* attributed to a notarized authority. Gatekeeper accepts other things too,
            // such as anything already on the system's own allow list. Matched at the start rather
            // than anywhere in the string: the source for a signed-but-unnotarized package is
            // "Unnotarized Developer ID", which contains the word either way.
            notarized: gatekeeper.accepted && isNotarized(source: gatekeeper.source),
            teamID: chain.teamID,
            authority: chain.authority ?? gatekeeper.origin,
            leafCertificateSHA256: chain.leaf
        )
    }

    // MARK: Contents

    struct Contents {
        var identifiers: [String] = []
        var version: String?
        var title: String?
        var hasScripts = false
        var scriptSummary: String?
        var hasRemoteReferences = false
    }

    /// Expand the package and read what it will install.
    ///
    /// `--expand` rather than `--expand-full`: the payloads stay as archives, which is all that is
    /// needed to know whether a component carries scripts, and avoids unpacking attacker-chosen
    /// archives as root just to look at them.
    static func contents(of path: String, expandingInto directory: String) async throws -> Contents {
        _ = try await ExecutionService.run("/usr/sbin/pkgutil", ["--expand", path, directory])

        var contents = Contents()

        let distribution = (directory as NSString).appendingPathComponent("Distribution")

        if FileManager.default.fileExists(atPath: distribution) {
            readDistribution(at: distribution, into: &contents)
        }

        for component in componentDirectories(in: directory) {
            readPackageInfo(at: (component as NSString).appendingPathComponent("PackageInfo"), into: &contents)

            // A `Scripts` archive beside the payload is the component's pre/postinstall scripts, and
            // they run as root. Its presence is enough; there is no need to unpack it.
            if FileManager.default.fileExists(atPath: (component as NSString).appendingPathComponent("Scripts")) {
                contents.hasScripts = true
                contents.scriptSummary = contents.scriptSummary ?? "install scripts that run as root"
            }
        }

        contents.identifiers = Array(Set(contents.identifiers)).sorted()

        return contents
    }

    private static func readDistribution(at path: String, into contents: inout Contents) {
        guard let document = try? XMLDocument(contentsOf: URL(fileURLWithPath: path), options: []) else {
            Logger.shared.logError("Unable to read the Distribution file at \(path)")
            return
        }

        contents.title = (try? document.nodes(forXPath: "//title"))?.first?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for node in (try? document.nodes(forXPath: "//pkg-ref")) ?? [] {
            guard let element = node as? XMLElement else { continue }

            if let id = element.attribute(forName: "id")?.stringValue, !id.isEmpty {
                contents.identifiers.append(id)
            }

            if contents.version == nil, let version = element.attribute(forName: "version")?.stringValue, !version.isEmpty {
                contents.version = version
            }

            // A reference whose body is a URL is fetched while installing. Those bytes arrive after
            // everything here has finished looking, so a package that has one can never be judged.
            let body = element.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if body.hasPrefix("http://") || body.hasPrefix("https://") {
                contents.hasRemoteReferences = true
            }
        }

        // JavaScript in the distribution runs inside the installer process, which is root here.
        if let scripts = try? document.nodes(forXPath: "//installer-gui-script/script"), !scripts.isEmpty {
            contents.hasScripts = true
            contents.scriptSummary = contents.scriptSummary ?? "installer JavaScript"
        }
    }

    private static func readPackageInfo(at path: String, into contents: inout Contents) {
        guard
            FileManager.default.fileExists(atPath: path),
            let document = try? XMLDocument(contentsOf: URL(fileURLWithPath: path), options: []),
            let root = document.rootElement()
        else { return }

        if let id = root.attribute(forName: "identifier")?.stringValue, !id.isEmpty {
            contents.identifiers.append(id)
        }

        if contents.version == nil, let version = root.attribute(forName: "version")?.stringValue, !version.isEmpty {
            contents.version = version
        }

        if let scripts = try? document.nodes(forXPath: "//scripts/*"), !scripts.isEmpty {
            contents.hasScripts = true
            contents.scriptSummary = contents.scriptSummary ?? "install scripts that run as root"
        }
    }

    // MARK: Payload

    /// Bundle extensions that are a destination in their own right, so a path stops there.
    private static let bundleExtensions: Set<String> = [
        "app", "framework", "bundle", "plugin", "kext", "prefPane", "qlgenerator", "xpc", "appex", "systemextension",
    ]

    /// The most roots a package may have before it is refused outright.
    ///
    /// Not a display limit — every one of these is checked. A package with more distinct destinations
    /// than this is pathological, and refusing is the only answer that does not involve deciding
    /// which of them not to look at.
    static let maximumRoots = 512

    /// Where a package's payload will land, shortened to the shallowest path containing each part.
    ///
    /// Read from each component's bill of materials, files and symlinks only. Directories are skipped
    /// deliberately: every package "installs" `/Applications` in the sense of ensuring it exists, and
    /// collapsing on that would report one useless root for everything.
    ///
    /// Each path is truncated at the first bundle it enters, or to three components, so an application
    /// reports `/Applications/Firefox.app` rather than ten thousand files. Truncation only ever moves
    /// a path towards the root, so a check against these roots also covers everything beneath them.
    static func payloadRoots(inExpanded directory: String) async throws -> [String] {
        var roots: Set<String> = []

        for component in componentDirectories(in: directory) {
            let bom = (component as NSString).appendingPathComponent("Bom")
            guard FileManager.default.fileExists(atPath: bom) else { continue }

            let installLocation = (try? XMLDocument(
                contentsOf: URL(fileURLWithPath: (component as NSString).appendingPathComponent("PackageInfo")),
                options: []
            ))?
                .rootElement()?
                .attribute(forName: "install-location")?
                .stringValue ?? "/"

            // A component whose bill of materials cannot be read contributes no destinations, and so
            // could never be blocked by any of them. For something deciding what root writes, "could
            // not look" has to mean "no", not "nothing to see".
            guard let output = try? await ExecutionService.run("/usr/bin/lsbom", ["-f", "-l", "-s", bom]) else {
                Logger.shared.logError("Unable to read the bill of materials at \(bom)")
                throw SupportCompanionErrors.helperConnection(
                    "Part of this package could not be read, so where it installs cannot be established"
                )
            }

            for line in output.split(separator: "\n") {
                let relative = line.hasPrefix(".") ? String(line.dropFirst()) : String(line)
                guard !relative.isEmpty, relative != "/" else { continue }

                let full = (installLocation as NSString).appendingPathComponent(relative)

                // AppleDouble sidecars carry the extended attributes of the file beside them and are
                // merged into it on arrival; they are metadata, not a destination of their own.
                // Reporting them would put `/Applications/._Foo.app` next to `/Applications/Foo.app`
                // and make any sensible prefix fail.
                guard !((full as NSString).lastPathComponent.hasPrefix("._")) else { continue }

                roots.insert(root(of: full))
            }

            // A symlink in the payload is a destination of its own: `installer` writes through it, so
            // a link at /Applications/Foo.app/Contents/x pointing at /Library/LaunchDaemons puts the
            // payload there while every nominal path still reads as being inside the app. Resolving
            // the target and treating it as another root means the ordinary prefix and deny-list
            // checks cover it, rather than needing a rule of their own.
            guard let links = try? await ExecutionService.run("/usr/bin/lsbom", ["-l", "-p", "fl", bom]) else {
                Logger.shared.logError("Unable to read the symbolic links in \(bom)")
                throw SupportCompanionErrors.helperConnection(
                    "Part of this package could not be read, so where it installs cannot be established"
                )
            }

            for line in links.split(separator: "\n") {
                let parts = line.split(separator: "\t", maxSplits: 1)
                guard parts.count == 2 else { continue }

                let linkPath = String(parts[0])
                let target = String(parts[1]).trimmingCharacters(in: .whitespaces)
                guard !target.isEmpty else { continue }

                let relative = linkPath.hasPrefix(".") ? String(linkPath.dropFirst()) : linkPath
                guard !((relative as NSString).lastPathComponent.hasPrefix("._")) else { continue }

                let full = (installLocation as NSString).appendingPathComponent(relative)

                let resolved = target.hasPrefix("/")
                    ? target
                    : ((full as NSString).deletingLastPathComponent as NSString).appendingPathComponent(target)

                roots.insert(root(of: resolved))
            }
        }

        let all = minimal(roots).sorted()

        // Never truncated here. This used to return at most a couple of dozen, which was harmless
        // while these were something to show the user — but they are now what the deny list is
        // checked against, so dropping one silently drops a refusal. A package with two dozen
        // destinations sorting before "/L" would have pushed /Library/LaunchDaemons off the end and
        // been allowed. Whatever is displayed is shortened at the point of display instead.
        guard all.count <= maximumRoots else {
            throw SupportCompanionErrors.helperConnection(
                "This package writes to \(all.count) different places, which is more than can be checked"
            )
        }

        return all
    }

    /// The directories holding a `PackageInfo`: one per component, or the package itself when it has
    /// no components of its own.
    private static func componentDirectories(in directory: String) -> [String] {
        var directories: [String] = []

        if FileManager.default.fileExists(atPath: (directory as NSString).appendingPathComponent("PackageInfo")) {
            directories.append(directory)
        }

        for entry in (try? FileManager.default.contentsOfDirectory(atPath: directory)) ?? [] {
            let path = (directory as NSString).appendingPathComponent(entry)

            if FileManager.default.fileExists(atPath: (path as NSString).appendingPathComponent("PackageInfo")) {
                directories.append(path)
            }
        }

        return directories
    }

    private static func root(of path: String) -> String {
        let components = (path as NSString).standardizingPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        var kept: [String] = []

        for component in components {
            kept.append(component)

            if bundleExtensions.contains((component as NSString).pathExtension) { break }
            if kept.count == 3 { break }
        }

        return "/" + kept.joined(separator: "/")
    }

    /// Drop any path that already sits inside another one in the set.
    private static func minimal(_ paths: Set<String>) -> [String] {
        var kept: [String] = []

        for path in paths.sorted() {
            if let last = kept.last, InstallerPolicy.isPath(path, under: last) { continue }
            kept.append(path)
        }

        return kept
    }

    // MARK: Facts

    /// Everything the policy needs to know about a staged package.
    static func facts(forStagedPackageAt path: String, fileName: String, expandingInto directory: String) async throws -> InstallerFacts {
        let digest = try StagedFile.sha256(ofFileAt: path)
        let signature = await signature(of: path)

        var facts = InstallerFacts(
            kind: .package,
            fileName: fileName,
            sha256: digest,
            teamID: signature.teamID,
            authority: signature.authority,
            leafCertificateSHA256: signature.leafCertificateSHA256,
            signatureTrusted: signature.trusted,
            notarized: signature.notarized
        )

        // A package that will not expand is not one we are going to install, but the digest and the
        // signature are still worth reporting: they are what an administrator needs to allow it.
        do {
            let contents = try await contents(of: path, expandingInto: directory)

            facts.identifiers = contents.identifiers
            facts.version = contents.version
            facts.displayName = contents.title
            facts.hasScripts = contents.hasScripts
            facts.scriptSummary = contents.scriptSummary
            facts.hasRemoteReferences = contents.hasRemoteReferences
        } catch {
            Logger.shared.logError("Unable to expand the package at \(path): \(error.localizedDescription)")
            throw SupportCompanionErrors.helperConnection("This does not look like an installer package")
        }

        // Outside the catch above, so that "where does this install" failing is reported as itself
        // rather than as "this is not a package".
        facts.payloadRoots = try await payloadRoots(inExpanded: directory)

        return facts
    }
}

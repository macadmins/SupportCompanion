//
//  DiskImageInspector.swift
//  com.github.macadmins.SupportCompanion.helper
//

import CryptoKit
import Foundation
import Security

/// Reads what a disk image contains, with the image mounted where only root can reach it.
///
/// A drag-install application needs no scripts and runs nothing as root — the install is a copy — but
/// it still needs the helper, because `/Applications` is `root:admin` and a standard user cannot write
/// to it. That makes this the safer half of the feature: what is checked and what is copied are the
/// same bytes, and nothing of the vendor's ever executes with privileges.
enum DiskImageInspector {

    // MARK: Mounting

    struct Mount {
        let mountPoint: String
        let deviceEntry: String
    }

    /// Attach the image underneath the staging directory.
    ///
    /// `-mountrandom` into our own root-owned, `0700` directory rather than `/Volumes`: mounted in
    /// `/Volumes` the user could read the image while it is being checked and, more to the point,
    /// replace what is at that path between the check and the copy.
    static func attach(imageAt path: String, under directory: String) async throws -> Mount {
        let mountRoot = (directory as NSString).appendingPathComponent("mnt")
        try HelperState.makeDirectory(at: mountRoot)

        // No stdin is attached to the helper, so an image with a licence agreement fails here rather
        // than waiting for an answer that cannot arrive. Those have to go through Installer.app.
        let output = try await ExecutionService.run("/usr/bin/hdiutil", [
            "attach", path,
            "-nobrowse", "-readonly", "-noautoopen", "-owners", "off",
            "-mountrandom", mountRoot,
            "-plist"
        ])

        guard
            let data = output.data(using: .utf8),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let entities = plist["system-entities"] as? [[String: Any]]
        else {
            throw SupportCompanionErrors.helperConnection("Unable to read what mounting the disk image produced")
        }

        guard let mounted = entities.first(where: { $0["mount-point"] is String }),
              let mountPoint = mounted["mount-point"] as? String
        else {
            throw SupportCompanionErrors.helperConnection("The disk image mounted nothing that can be read")
        }

        // Detaching wants the whole image's device, which is the shortest of the entries.
        let deviceEntry = entities
            .compactMap { $0["dev-entry"] as? String }
            .min(by: { $0.count < $1.count })
            ?? (mounted["dev-entry"] as? String ?? mountPoint)

        return Mount(mountPoint: mountPoint, deviceEntry: deviceEntry)
    }

    static func detach(_ mount: Mount) async {
        do {
            _ = try await ExecutionService.run("/usr/bin/hdiutil", ["detach", mount.deviceEntry, "-quiet"])
        } catch {
            Logger.shared.logError("Unable to detach \(mount.deviceEntry): \(error.localizedDescription). Forcing.")
            _ = try? await ExecutionService.run("/usr/bin/hdiutil", ["detach", mount.deviceEntry, "-force", "-quiet"])
        }
    }

    // MARK: Contents

    enum Payload {
        case application(path: String)
        case package(path: String)
    }

    /// Find the one thing in the image that can be installed.
    ///
    /// Exactly one, and only at the top level. An image holding two applications, or one tucked inside
    /// a folder, is refused rather than guessed at: the guess would decide what gets installed as root.
    static func payload(in mountPoint: String) throws -> Payload {
        let entries = try FileManager.default.contentsOfDirectory(atPath: mountPoint)
            .filter { !$0.hasPrefix(".") }

        let applications = try entries
            .filter { ($0 as NSString).pathExtension.lowercased() == "app" }
            .map { try validatedEntry($0, in: mountPoint) }

        let packages = try entries
            .filter { ["pkg", "mpkg"].contains(($0 as NSString).pathExtension.lowercased()) }
            .map { try validatedEntry($0, in: mountPoint) }

        if applications.count == 1 && packages.isEmpty {
            return .application(path: applications[0])
        }

        if packages.count == 1 && applications.isEmpty {
            return .package(path: packages[0])
        }

        if applications.isEmpty && packages.isEmpty {
            throw SupportCompanionErrors.helperConnection("The disk image contains no application or installer package")
        }

        throw SupportCompanionErrors.helperConnection(
            "The disk image contains more than one installable item, so there is no way to tell which one was meant"
        )
    }

    /// Refuse a payload that is a symbolic link, or that resolves outside the image.
    ///
    /// A disk image is authored by whoever handed it over, and a link in it is resolved at the moment
    /// it is used — by the helper, as root. An image containing `Vendor.pkg -> ~/their.pkg` would have
    /// the allowlist checked against a file the user can replace afterwards, which is the whole
    /// guarantee of this feature turned inside out. The image's own digest says nothing about it,
    /// because the image genuinely is the one that was approved.
    ///
    /// Every drag-install image contains an `Applications` symlink, so links are ordinary here; it is
    /// only a link *as the payload* that is refused.
    private static func validatedEntry(_ name: String, in mountPoint: String) throws -> String {
        let path = (mountPoint as NSString).appendingPathComponent(name)

        var info = stat()

        guard lstat(path, &info) == 0 else {
            throw SupportCompanionErrors.helperConnection("Unable to read '\(name)' in the disk image")
        }

        guard (info.st_mode & S_IFMT) != S_IFLNK else {
            Logger.shared.logError("Refusing \(path): the payload is a symbolic link")
            throw SupportCompanionErrors.helperConnection("'\(name)' is a link rather than something this can install")
        }

        // Belt and braces for any other way out of the mount, such as a firmlink.
        let resolved = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        let root = URL(fileURLWithPath: mountPoint).resolvingSymlinksInPath().path

        guard resolved == root || resolved.hasPrefix(root.hasSuffix("/") ? root : root + "/") else {
            Logger.shared.logError("Refusing \(path): it resolves to \(resolved), outside the disk image")
            throw SupportCompanionErrors.helperConnection("'\(name)' points outside the disk image")
        }

        return path
    }

    /// Copy the payload out of the mounted image into root-owned staging.
    ///
    /// So that the image can be detached before anything is installed, and so that what was inspected
    /// and what gets installed are one set of bytes in a directory only root can write. While the
    /// payload is still inside the image it is only as stable as the image's author allows.
    static func copyOut(_ payload: Payload, into directory: String) async throws -> Payload {
        let destinationDirectory = (directory as NSString).appendingPathComponent("payload")
        try HelperState.makeDirectory(at: destinationDirectory)

        let source: String
        switch payload {
        case .application(let path): source = path
        case .package(let path): source = path
        }

        let destination = (destinationDirectory as NSString)
            .appendingPathComponent((source as NSString).lastPathComponent)

        // `ditto` keeps the bundle intact, including the extended attributes a signature depends on.
        _ = try await ExecutionService.run("/usr/bin/ditto", ["--noqtn", source, destination])

        switch payload {
        case .application: return .application(path: destination)
        case .package: return .package(path: destination)
        }
    }

    // MARK: Application signature

    struct ApplicationSignature {
        var trusted = false
        var notarized = false
        var teamID: String?
        var bundleIdentifier: String?
        var authority: String?
        var leafCertificateSHA256: String?
    }

    /// Verify an application bundle's signature and read who signed it.
    ///
    /// `anchor apple generic` establishes that the signature chains to Apple; the Team ID and the
    /// bundle identifier are then read from the signature itself rather than from `Info.plist`, which
    /// is not evidence of anything — a bundle can claim any identifier it likes in a file, but only the
    /// one it was signed with survives `SecStaticCodeCheckValidity`.
    static func signature(ofApplicationAt path: String) async -> ApplicationSignature {
        var signature = ApplicationSignature()

        var staticCode: SecStaticCode?

        guard SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
              let staticCode
        else {
            Logger.shared.logError("Unable to read a code signature from \(path)")
            return signature
        }

        var requirement: SecRequirement?

        guard SecRequirementCreateWithString("anchor apple generic" as CFString, [], &requirement) == errSecSuccess else {
            return signature
        }

        // Every architecture, and the nested code too: a bundle can be signed correctly at the top
        // level while carrying a helper or framework inside it that is not.
        let flags = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        let validity = SecStaticCodeCheckValidity(staticCode, flags, requirement)

        guard validity == errSecSuccess else {
            Logger.shared.logError("\(path) failed signature validation with status \(validity)")
            return signature
        }

        signature.trusted = true

        var information: CFDictionary?

        if SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
           let info = information as? [String: Any] {
            signature.teamID = info[kSecCodeInfoTeamIdentifier as String] as? String
            signature.bundleIdentifier = info[kSecCodeInfoIdentifier as String] as? String

            // Taken from the certificate itself rather than parsed out of a printed chain, which is
            // what the package side has to settle for. Same value, same profile key.
            if let certificates = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
               let leaf = certificates.first {
                let der = SecCertificateCopyData(leaf) as Data
                signature.leafCertificateSHA256 = SHA256.hash(data: der)
                    .map { String(format: "%02x", $0) }
                    .joined()
            }
        }

        let assessment = await gatekeeperAssessment(of: path)
        signature.notarized = assessment.notarized
        signature.authority = assessment.origin

        return signature
    }

    /// Read an application's signing identifier without requiring its signature to be valid.
    ///
    /// `signature(ofApplicationAt:)` answers "is this trustworthy" and gives up as soon as validation
    /// fails, so it reports no identifier at all for an application that is unsigned, ad-hoc signed,
    /// or has a broken nested signature. That is precisely the incumbent you want to identify before
    /// replacing it. This asks only what the bundle says it is, and says so where it can.
    ///
    /// It is also cheap: no nested-code walk and no Gatekeeper fork, which on a large application is
    /// seconds spent reading one string.
    static func identifier(ofApplicationAt path: String) -> String? {
        var staticCode: SecStaticCode?

        if SecStaticCodeCreateWithPath(URL(fileURLWithPath: path) as CFURL, [], &staticCode) == errSecSuccess,
           let staticCode {
            var information: CFDictionary?

            if SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information) == errSecSuccess,
               let info = information as? [String: Any],
               let identifier = info[kSecCodeInfoIdentifier as String] as? String {
                return identifier
            }
        }

        // Unsigned entirely. Info.plist is not evidence of anything, but for deciding whether two
        // bundles are the same application it is better than knowing nothing.
        return Bundle(path: path)?.bundleIdentifier
    }

    /// Ask Gatekeeper to assess the application the way launching it would.
    ///
    /// As with packages, an assessment on a Mac where Gatekeeper has been turned off approves
    /// everything, so a disabled assessment is reported as "not notarized" rather than as a pass.
    private static func gatekeeperAssessment(of path: String) async -> (notarized: Bool, origin: String?) {
        let status = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/spctl"),
            arguments: ["--status"]
        )

        let statusOutput = (String(data: status?.output ?? Data(), encoding: .utf8) ?? "")
            + (String(data: status?.error ?? Data(), encoding: .utf8) ?? "")

        guard statusOutput.contains("assessments enabled") else {
            Logger.shared.logError("Gatekeeper assessments are disabled on this Mac; treating \(path) as unassessed")
            return (false, nil)
        }

        let result = try? await ProcessRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/spctl"),
            arguments: ["--assess", "--type", "execute", "-vv", path]
        )

        guard let result else { return (false, nil) }

        let output = (String(data: result.output, encoding: .utf8) ?? "")
            + (String(data: result.error, encoding: .utf8) ?? "")

        let lines = output.split(separator: "\n")
        let source = lines.first { $0.hasPrefix("source=") }.map { String($0.dropFirst(7)) }
        let origin = lines.first { $0.hasPrefix("origin=") }.map { String($0.dropFirst(7)) }

        return (result.status == 0 && PackageInspector.isNotarized(source: source), origin)
    }

    // MARK: Facts

    /// What the policy needs to know about an application inside a mounted image.
    ///
    /// The digest is of the disk image the user downloaded, not of the application inside it: that is
    /// the file an administrator can hash to write a strict-mode entry.
    static func facts(
        forApplicationAt path: String,
        imageDigest: String,
        fileName: String
    ) async throws -> InstallerFacts {
        let signature = await signature(ofApplicationAt: path)

        let bundle = Bundle(path: path)
        let version = bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: "")

        return InstallerFacts(
            kind: .diskImage,
            fileName: fileName,
            sha256: imageDigest,
            teamID: signature.teamID,
            authority: signature.authority,
            leafCertificateSHA256: signature.leafCertificateSHA256,
            signatureTrusted: signature.trusted,
            notarized: signature.notarized,
            identifiers: [signature.bundleIdentifier].compactMap { $0 },
            displayName: displayName,
            version: version,
            hasScripts: false,
            hasRemoteReferences: false,
            // A drag install writes one place, and `installApplication` will not write anywhere else.
            payloadRoots: ["/Applications/\((path as NSString).lastPathComponent)"]
        )
    }
}

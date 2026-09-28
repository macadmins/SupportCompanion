//
//  InstallCoordinator.swift
//  com.github.macadmins.SupportCompanion.helper
//

import Darwin
import Foundation

/// Installs applications an administrator has allowed, on behalf of a user who is not an administrator.
///
/// The work is in two steps on purpose. `stage` copies the installer somewhere only root can write and
/// judges it *there*; `install` installs that same copy, named only by an opaque token. Nothing the
/// client says between the two can change what gets installed, so this keeps the property the rest of
/// the helper has: the caller names an operation, and the helper decides what it does.
actor InstallCoordinator {

    static let shared = InstallCoordinator()

    private static let auditLogPath = HelperState.directory + "/installs.log"

    /// How long a staged installer waits for the user to make up their mind.
    ///
    /// A disk image stays mounted for this long, so it is short. The app re-stages if the sheet has
    /// been sitting open longer than this.
    private static let stagingLifetime: TimeInterval = 5 * 60

    private struct Staged {
        let directory: String
        /// The package to install, or the application to copy.
        let payloadPath: String
        let kind: InstallerFacts.Kind
        let mount: DiskImageInspector.Mount?
        let facts: InstallerFacts
        let entryName: String
        let matchMode: InstallerMatchMode
        let clientUID: uid_t
        let createdAt: Date
    }

    private var staged: [String: Staged] = [:]

    /// Disk images attached while an assessment is still running, by staging directory.
    ///
    /// On the actor rather than in a local, so that cleaning up after a failure part-way through the
    /// assessment can find what was mounted. A directory holding a mount point cannot be removed until
    /// the image is detached, and detaching is asynchronous, so this cannot live in a `defer`.
    private var mountsInProgress: [String: DiskImageInspector.Mount] = [:]

    /// Only one install at a time. Without this a client can start as many root `installer` processes
    /// as it can click, and two installs writing to `/Applications` at once is its own problem.
    private var isInstalling = false

    private init() {}

    // MARK: Launch

    /// Clear anything a previous run left behind.
    ///
    /// A crash mid-assessment leaves a staged copy, and possibly a disk image still attached. Neither
    /// is dangerous — both are inside a root-only directory — but they occupy disk until something
    /// tidies up, and nothing else will.
    nonisolated func reconcileOnLaunch() {
        Task { await tidyLeftovers() }
    }

    private func tidyLeftovers() async {
        guard FileManager.default.fileExists(atPath: StagedFile.root) else { return }

        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: StagedFile.root)) ?? []

        for leftover in leftovers {
            let directory = (StagedFile.root as NSString).appendingPathComponent(leftover)
            let mountRoot = (directory as NSString).appendingPathComponent("mnt")

            for mounted in (try? FileManager.default.contentsOfDirectory(atPath: mountRoot)) ?? [] {
                let path = (mountRoot as NSString).appendingPathComponent(mounted)
                _ = try? await ExecutionService.run("/usr/bin/hdiutil", ["detach", path, "-force", "-quiet"])
            }

            StagedFile.remove(directory)
            Logger.shared.logInfo("Removed a staged installer left behind by a previous run")
        }
    }

    // MARK: Staging

    /// Copy an installer out of the user's reach, work out what it is, and decide whether it is allowed.
    func stage(
        from handle: FileHandle,
        fileName: String,
        clientUID: uid_t,
        clientUserName: String
    ) async throws -> InstallerAssessment {
        await expireStale()

        // The app hides all of this when it is off, but that is presentation. This is the check that
        // decides, and it reads a preference only an administrator can write.
        //
        // This throws before anything is staged, which means nothing reaches the audit log either. An
        // empty `installs.log` and a feature that appears to do nothing are the same symptom, so the
        // reason travels back to the client rather than only being implied by the silence.
        guard HelperPreferences.enableUserInstalls(forUser: clientUserName) else {
            let searched = HelperPreferences.describeSearch(forKey: "EnableUserInstalls", forUser: clientUserName)
            Logger.shared.logError("Refusing to stage an installer for \(clientUserName): EnableUserInstalls is not set. \(searched)")

            throw SupportCompanionErrors.helperConnection(
                "Installing applications is not enabled by an administrator. The helper read: \(searched)"
            )
        }

        let directory = try StagedFile.makeStagingDirectory()

        do {
            return try await assess(
                from: handle,
                fileName: fileName,
                clientUID: clientUID,
                clientUserName: clientUserName,
                directory: directory
            )
        } catch {
            await cleanUp(directory: directory)
            throw error
        }
    }

    /// The body of `stage`, split out so its caller can clean up after any failure in it.
    private func assess(
        from handle: FileHandle,
        fileName: String,
        clientUID: uid_t,
        clientUserName: String,
        directory: String
    ) async throws -> InstallerAssessment {
        let fallback = HelperPreferences.installFallback(forUser: clientUserName)
        let requiresAuthentication = HelperPreferences.requireAuthenticationForInstalls(forUser: clientUserName)

        let stagedPath = try StagedFile.copy(from: handle, toDirectory: directory, fileName: fileName)

        let facts: InstallerFacts
        let payloadPath: String
        let kind: InstallerFacts.Kind

        switch (fileName as NSString).pathExtension.lowercased() {
        case "dmg":
            let attached = try await DiskImageInspector.attach(imageAt: stagedPath, under: directory)
            mountsInProgress[directory] = attached

            let digest = try StagedFile.sha256(ofFileAt: stagedPath)

            // Copy the payload into root-owned staging and let the image go before anything is
            // inspected. While it stays mounted, everything below is reading something whose author
            // can still change it — the image's own digest says nothing about where a link inside it
            // points. What is assessed and what is installed have to be one set of bytes.
            let copied = try await DiskImageInspector.copyOut(
                DiskImageInspector.payload(in: attached.mountPoint),
                into: directory
            )

            await DiskImageInspector.detach(attached)
            mountsInProgress[directory] = nil

            switch copied {
            case .application(let applicationPath):
                facts = try await DiskImageInspector.facts(
                    forApplicationAt: applicationPath,
                    imageDigest: digest,
                    fileName: fileName
                )
                payloadPath = applicationPath
                kind = .diskImage

            case .package(let packagePath):
                // An installer package inside a disk image installs like any other package. The digest
                // stays that of the image, because that is the file the user downloaded and the one an
                // administrator would hash for a strict-mode entry.
                var packageFacts = try await PackageInspector.facts(
                    forStagedPackageAt: packagePath,
                    fileName: fileName,
                    expandingInto: (directory as NSString).appendingPathComponent("expanded")
                )
                packageFacts.sha256 = digest

                facts = packageFacts
                payloadPath = packagePath
                kind = .package
            }

        case "pkg", "mpkg":
            facts = try await PackageInspector.facts(
                forStagedPackageAt: stagedPath,
                fileName: fileName,
                expandingInto: (directory as NSString).appendingPathComponent("expanded")
            )
            payloadPath = stagedPath
            kind = .package

        default:
            throw SupportCompanionErrors.helperConnection("Support Companion can only install .pkg and .dmg files")
        }

        let allowlist = HelperPreferences.allowedInstallers(forUser: clientUserName)
        let decision = InstallerPolicy.evaluate(facts, against: allowlist)

        guard let entry = decision.entry else {
            log(refusalOf: facts, for: clientUserName, reasons: decision.logReasons)

            // Nothing is kept for an installer nobody allowed: there is no token to install it with,
            // so the copy and any mounted image would only sit there until they expired.
            await cleanUp(directory: directory)

            return InstallerAssessment(
                token: nil,
                // Shortened only now, after the policy has seen every destination.
                facts: facts.shortenedForDisplay(),
                isAllowed: false,
                matchedEntry: nil,
                matchMode: nil,
                rejectionReasons: decision.reasons,
                fallback: fallback,
                requiresAuthentication: requiresAuthentication
            )
        }

        let token = UUID().uuidString

        staged[token] = Staged(
            directory: directory,
            payloadPath: payloadPath,
            kind: kind,
            mount: mountsInProgress.removeValue(forKey: directory),
            facts: facts,
            entryName: entry.name,
            matchMode: entry.mode,
            clientUID: clientUID,
            createdAt: Date()
        )

        log(approvalOf: facts, for: clientUserName, entry: entry)

        return InstallerAssessment(
            token: token,
            facts: facts.shortenedForDisplay(),
            isAllowed: true,
            matchedEntry: entry.name,
            matchMode: entry.mode,
            rejectionReasons: [],
            fallback: fallback,
            requiresAuthentication: requiresAuthentication
        )
    }

    // MARK: Installing

    /// Install what was staged under `token`.
    func install(token: String, clientUID: uid_t, clientUserName: String) async throws -> String {
        await expireStale()

        guard let entry = staged[token] else {
            throw SupportCompanionErrors.helperConnection("That installer is no longer ready. Open it again.")
        }

        // The token came back from this helper, but only to one connection. Another user logged in at
        // the same time must not be able to install something the first one staged.
        guard entry.clientUID == clientUID else {
            Logger.shared.logError("Refusing to install \(entry.facts.fileName): staged for uid \(entry.clientUID), asked for by uid \(clientUID)")
            throw SupportCompanionErrors.helperConnection("That installer was prepared for a different user")
        }

        guard HelperPreferences.enableUserInstalls(forUser: clientUserName) else {
            throw SupportCompanionErrors.helperConnection("Installing applications from Support Companion is not enabled by an administrator")
        }

        guard !isInstalling else {
            throw SupportCompanionErrors.helperConnection("Another installation is already running")
        }

        isInstalling = true

        // Not a `defer`: the staged copy holds a mounted disk image, and detaching it has to be
        // awaited before the directory it is mounted inside can be removed. A token is good for one
        // install either way, so it goes whether or not the install worked.
        do {
            // Checked here rather than during assessment: what is on disk at the destination can
            // change between the two, and this is the last moment before root writes anything.
            try refuseIfDestinationsAreRedirected(entry.facts.payloadRoots)

            let output: String

            switch entry.kind {
            case .package:
                output = try await ExecutionService.run("/usr/sbin/installer", ["-pkg", entry.payloadPath, "-target", "/"])
            case .diskImage:
                output = try await installApplication(at: entry.payloadPath, approved: entry.facts, pinnedByDigest: entry.matchMode == .strict)
            }

            HelperState.appendLine(
                "installed user=\(clientUserName) file=\(entry.facts.fileName) entry=\(entry.entryName) version=\(entry.facts.version ?? "?") sha256=\(entry.facts.sha256)",
                toLogAt: Self.auditLogPath
            )

            isInstalling = false
            await discard(token)

            return output
        } catch {
            HelperState.appendLine(
                "failed user=\(clientUserName) file=\(entry.facts.fileName) entry=\(entry.entryName) error=\(error.localizedDescription)",
                toLogAt: Self.auditLogPath
            )

            isInstalling = false
            await discard(token)

            throw error
        }
    }

    /// Copy a verified application into `/Applications`.
    ///
    /// Nothing of the vendor's runs here — it is a copy — but it is a copy made by root into a
    /// directory every account can see, so the name is checked, the previous version is kept until the
    /// new one is in place, and the result is verified where it landed before the old one is let go.
    private func installApplication(at path: String, approved: InstallerFacts, pinnedByDigest: Bool) async throws -> String {
        let name = (path as NSString).lastPathComponent

        guard !name.isEmpty, !name.hasPrefix("."), !name.contains("/"), name.hasSuffix(".app") else {
            throw SupportCompanionErrors.helperConnection("'\(name)' is not a name this can install")
        }

        let destination = "/Applications/\(name)"

        // The name comes from the disk image, so it decides what gets replaced. Replacing one
        // application with a different one that merely happens to be allowed is not an install, it is
        // a substitution — and on a shared Mac it changes what somebody else launches.
        if FileManager.default.fileExists(atPath: destination) {
            // Read without requiring validity: an unsigned or broken incumbent would otherwise report
            // no identifier, the comparison would be skipped, and the replacement would go ahead —
            // which is the case this check exists for.
            let existingIdentifier = DiskImageInspector.identifier(ofApplicationAt: destination)
            let incoming = approved.identifiers.first

            guard let existingIdentifier, let incoming else {
                throw SupportCompanionErrors.helperConnection(
                    "\(name) is already installed and could not be identified, so it has been left alone."
                )
            }

            guard existingIdentifier == incoming else {
                throw SupportCompanionErrors.helperConnection(
                    "\(name) is already installed and is a different application (\(existingIdentifier)). It has been left alone."
                )
            }
        }

        // Nothing is moved or copied while the application is running: `ditto` would replace a bundle
        // out from under a live process, and if the verification below then fails, the rollback would
        // put the old one back underneath something that has been running out of a half-replaced one.
        if isRunning(applicationAt: destination) {
            throw SupportCompanionErrors.helperConnection(
                "\(name.replacingOccurrences(of: ".app", with: "")) is open. Quit it and try again."
            )
        }

        // Kept on the same volume so the move is a rename and cannot half-happen.
        let previous = "/Applications/.\(name).supportcompanion-previous"
        StagedFile.remove(previous)

        let hadPrevious = FileManager.default.fileExists(atPath: destination)

        if hadPrevious {
            try FileManager.default.moveItem(atPath: destination, toPath: previous)
        }

        do {
            _ = try await ExecutionService.run("/usr/bin/ditto", [path, destination])

            // Ownership follows the disk image otherwise, which is whatever the vendor built it as.
            _ = try await ExecutionService.run("/usr/sbin/chown", ["-R", "root:admin", destination])

            // The signature was checked on the image and is checked again below, so Gatekeeper has
            // nothing left to ask the user on first launch. Leaving the attribute on would produce a
            // "downloaded from the internet" prompt for something an administrator allowed.
            _ = try? await ExecutionService.run("/usr/bin/xattr", ["-d", "-r", "com.apple.quarantine", destination])

            // Not merely "is it signed". The copy has to be the application that was assessed:
            // anything validly signed satisfies `anchor apple generic`, including an application the
            // allowlist has never heard of, which would make this check the opposite of a safeguard.
            let verified = await DiskImageInspector.signature(ofApplicationAt: destination)

            guard verified.trusted else {
                throw SupportCompanionErrors.helperConnection("The copy in /Applications does not verify, so it has been removed")
            }

            // `==` alone would be satisfied by both being nil. That is only reachable in strict
            // mode, where the digest pins the image — but it is sound because of a rule enforced in
            // another file, so it is stated here rather than relied upon quietly.
            guard approved.teamID != nil || pinnedByDigest else {
                throw SupportCompanionErrors.helperConnection(
                    "The approved application has no signing team and was not pinned by digest, so the copy cannot be confirmed. It has been removed."
                )
            }

            guard verified.teamID == approved.teamID else {
                throw SupportCompanionErrors.helperConnection(
                    "The copy in /Applications is signed by \(verified.teamID ?? "nobody"), not \(approved.teamID ?? "the approved team"). It has been removed."
                )
            }

            guard let installedIdentifier = verified.bundleIdentifier,
                  approved.identifiers.contains(installedIdentifier) else {
                throw SupportCompanionErrors.helperConnection(
                    "The copy in /Applications identifies as \(verified.bundleIdentifier ?? "nothing"), which is not what was approved. It has been removed."
                )
            }
        } catch {
            StagedFile.remove(destination)

            if hadPrevious {
                try? FileManager.default.moveItem(atPath: previous, toPath: destination)
            }

            throw error
        }

        StagedFile.remove(previous)

        return "Installed \(name) in /Applications"
    }

    /// Refuse when something already on disk would send the install somewhere else.
    ///
    /// `installer` writes *through* a symbolic link standing at a destination path — a link at
    /// `/Applications/Foo.app` pointing at `/tmp/escape` puts the package's payload in `/tmp/escape`,
    /// with no complaint and a successful exit. Nothing in the package says so, so no amount of
    /// inspecting it helps.
    ///
    /// That matters here more than it would elsewhere, because this app also hands out temporary
    /// administrator rights: somebody can plant the link while elevated, let the window close, and
    /// then use an allowlisted installer to write wherever the link points, as root.
    ///
    /// `/etc`, `/var` and `/tmp` are links macOS ships with and are left alone.
    private func refuseIfDestinationsAreRedirected(_ roots: [String]) throws {
        let systemLinks = ["/etc", "/var", "/tmp"]

        for root in roots {
            var current = ""

            for component in (root as NSString).pathComponents where component != "/" {
                current += "/" + component

                var info = stat()

                // Nothing there yet, so nothing below it either.
                guard lstat(current, &info) == 0 else { break }

                guard (info.st_mode & S_IFMT) == S_IFLNK else { continue }
                guard !systemLinks.contains(current) else { continue }

                let target = (try? FileManager.default.destinationOfSymbolicLink(atPath: current)) ?? "somewhere else"

                Logger.shared.logError("Refusing to install: \(current) is a link to \(target)")

                throw SupportCompanionErrors.helperConnection(
                    "\(current) is a link to \(target), so installing would write somewhere other than where this package says. Nothing has been installed."
                )
            }
        }
    }

    /// Whether the application at `path` is running.
    ///
    /// Asked of the kernel rather than of `pgrep -f`, which takes a POSIX regular expression. The
    /// bundle name comes out of a disk image somebody else authored, and escaping it for the wrong
    /// flavour of regex fails in the unsafe direction: an escape the matcher does not recognise means
    /// no match, which reads as "not running", and the copy goes over a live application.
    private func isRunning(applicationAt path: String) -> Bool {
        let prefix = path + "/Contents/MacOS/"

        var count = proc_listallpids(nil, 0)
        guard count > 0 else { return false }

        // Room for processes started between asking the size and asking for the list.
        count += 64

        var pids = [pid_t](repeating: 0, count: Int(count))
        let bytes = proc_listallpids(&pids, Int32(MemoryLayout<pid_t>.size) * count)
        guard bytes > 0 else { return false }

        let found = Int(bytes) / MemoryLayout<pid_t>.size

        for pid in pids.prefix(found) where pid > 0 {
            // PROC_PIDPATHINFO_MAXSIZE, which Darwin does not surface to Swift: 4 * MAXPATHLEN.
            var buffer = [CChar](repeating: 0, count: 4 * 1024)

            guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else { continue }

            if String(cString: buffer).hasPrefix(prefix) { return true }
        }

        return false
    }

    // MARK: Lifetime

    /// Detach anything mounted under a staging directory, then remove it.
    ///
    /// In that order: the directory holds the mount point, so removing it first would either fail or
    /// leave the image attached with nothing pointing at it.
    private func cleanUp(directory: String, mount: DiskImageInspector.Mount? = nil) async {
        if let mount = mount ?? mountsInProgress.removeValue(forKey: directory) {
            await DiskImageInspector.detach(mount)
        }

        StagedFile.remove(directory)
    }

    func discard(_ token: String) async {
        guard let entry = staged.removeValue(forKey: token) else { return }
        await cleanUp(directory: entry.directory, mount: entry.mount)
    }

    func discard(_ token: String, clientUID: uid_t) async {
        guard let entry = staged[token], entry.clientUID == clientUID else { return }
        await discard(token)
    }

    private func expireStale() async {
        let cutoff = Date().addingTimeInterval(-Self.stagingLifetime)

        for (token, entry) in staged where entry.createdAt < cutoff {
            Logger.shared.logDebug("Discarding staged installer \(entry.facts.fileName): nothing decided within \(Int(Self.stagingLifetime))s")
            await discard(token)
        }
    }

    // MARK: Audit

    private func log(approvalOf facts: InstallerFacts, for userName: String, entry: AllowedInstaller) {
        HelperState.appendLine(
            "allowed user=\(userName) file=\(facts.fileName) kind=\(facts.kind.rawValue) id=\(facts.identifiers.joined(separator: ",")) version=\(facts.version ?? "?") team=\(facts.teamID ?? "?") notarized=\(facts.notarized) sha256=\(facts.sha256) paths=\(facts.payloadRoots.joined(separator: ",")) entry=\(entry.name) mode=\(entry.mode.rawValue)",
            toLogAt: Self.auditLogPath
        )
    }

    private func log(refusalOf facts: InstallerFacts, for userName: String, reasons: [String]) {
        HelperState.appendLine(
            "refused user=\(userName) file=\(facts.fileName) kind=\(facts.kind.rawValue) id=\(facts.identifiers.joined(separator: ",")) version=\(facts.version ?? "?") team=\(facts.teamID ?? "?") sha256=\(facts.sha256) paths=\(facts.payloadRoots.joined(separator: ",")) reasons=\(reasons.joined(separator: "; "))",
            toLogAt: Self.auditLogPath
        )
    }
}

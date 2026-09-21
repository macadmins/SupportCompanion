//
//  ElevationCoordinator.swift
//  com.github.macadmins.SupportCompanion.helper
//

import Foundation

/// Owns temporary administrator rights: who has them, until when, and taking them back.
///
/// The app used to run the demotion timer itself and keep the deadline in the user's own defaults, which
/// made the time limit a suggestion — quitting the app, or deleting the key, left the user an administrator
/// indefinitely. Both the deadline and the timer live here instead, in a root-owned file and in a process
/// the user cannot stop, so the limit holds even if the app never runs again.
///
/// Several users can be elevated at once. With fast user switching two accounts can each be logged in and
/// each ask for rights, and one window must not silently replace the other: whoever it discarded would keep
/// administrator rights with nothing left to take them away.
final class ElevationCoordinator: @unchecked Sendable {

    static let shared = ElevationCoordinator()

    // Not under /Library/Application Support: the app creates its folder there while running as the
    // user, so that folder is owned by the user, and whoever owns a directory can replace or delete
    // what is in it. A deadline the elevated user can rewrite is not a deadline. /var/db is root-owned
    // and is where daemon state belongs.
    private static let stateDirectory = "/var/db/com.github.macadmins.SupportCompanion"
    private static let statePath = stateDirectory + "/elevation.plist"
    private static let auditLogPath = stateDirectory + "/elevation.log"

    /// How often the admin group is re-read while a window is open.
    ///
    /// One `dscl` read costs about 15ms, so this is a low single-digit percentage of one core while
    /// somebody is elevated, and nothing at all the rest of the time.
    private static let watchdogInterval: DispatchTimeInterval = .seconds(1)

    /// How often the admin group is reconciled against the allowlist, independently of any elevation.
    ///
    /// The allowlist comes from a configuration profile, which a user with root can delete. Their MDM
    /// puts it back, but nothing would re-read it until the helper restarted, so a reboot-free bypass
    /// would otherwise stay open indefinitely. Re-reading on a timer bounds it to the MDM's sync
    /// interval plus this.
    private static let reconcileInterval: DispatchTimeInterval = .seconds(300)

    /// How much of an elevation reason is kept in the audit log.
    private static let maximumReasonLength = 512

    private let queue = DispatchQueue(label: "com.github.macadmins.SupportCompanion.helper.elevation")
    private var timers: [String: DispatchSourceTimer] = [:]
    private var watchdog: DispatchSourceTimer?
    private var reconciler: DispatchSourceTimer?
    private var isCheckingAdmins = false

    private init() {}

    // MARK: State

    private struct Elevation {
        let userName: String
        let deadline: Date
        /// Who was an administrator when this window opened. Anyone who appears later was added
        /// during it, by somebody who only has the rights to do so because we granted them.
        let baseline: AdminSnapshot

        var isActive: Bool { deadline > Date() }
    }

    /// The `admin` group as OpenDirectory records it, in both forms.
    ///
    /// Membership can be granted by short name or by UUID, and either one is enough to be an
    /// administrator, so watching only the names would leave the other way in unwatched.
    struct AdminSnapshot: Equatable {
        var names: Set<String> = []
        var uuids: Set<String> = []

        func additions(over baseline: AdminSnapshot) -> AdminSnapshot {
            AdminSnapshot(
                names: names.subtracting(baseline.names),
                uuids: uuids.subtracting(baseline.uuids)
            )
        }

        var isEmpty: Bool { names.isEmpty && uuids.isEmpty }
    }

    private static func elevation(from dictionary: [String: Any]) -> Elevation? {
        guard
            let userName = dictionary["UserName"] as? String,
            let deadline = dictionary["Deadline"] as? Date
        else { return nil }

        return Elevation(
            userName: userName,
            deadline: deadline,
            baseline: AdminSnapshot(
                names: Set(dictionary["BaselineAdminNames"] as? [String] ?? []),
                uuids: Set(dictionary["BaselineAdminUUIDs"] as? [String] ?? [])
            )
        )
    }

    private func loadElevations() -> [Elevation] {
        prepareStateDirectory()

        guard FileManager.default.fileExists(atPath: Self.statePath) else { return [] }

        // With the directory locked down this cannot happen, which is exactly why it is worth
        // noticing if it ever does.
        guard isOwnedByRoot(Self.statePath) else {
            Logger.shared.logError("Discarding elevation state at \(Self.statePath): not owned by root")
            try? FileManager.default.removeItem(atPath: Self.statePath)
            return []
        }

        guard
            let data = FileManager.default.contents(atPath: Self.statePath),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        else { return [] }

        if let entries = plist["Elevations"] as? [[String: Any]] {
            return entries.compactMap(Self.elevation(from:))
        }

        // A file written before this held one elevation at the top level. Read it so a window that is
        // open across an upgrade is still closed rather than stranded.
        return [Self.elevation(from: plist)].compactMap { $0 }
    }

    private func saveElevations(_ elevations: [Elevation]) {
        guard !elevations.isEmpty else {
            try? FileManager.default.removeItem(atPath: Self.statePath)
            return
        }

        prepareStateDirectory()

        let plist: [String: Any] = [
            "Elevations": elevations.map { elevation in
                [
                    "UserName": elevation.userName,
                    "Deadline": elevation.deadline,
                    "BaselineAdminNames": Array(elevation.baseline.names),
                    "BaselineAdminUUIDs": Array(elevation.baseline.uuids)
                ] as [String: Any]
            }
        ]

        guard let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) else {
            Logger.shared.logError("Unable to serialize elevation state")
            return
        }

        FileManager.default.createFile(
            atPath: Self.statePath,
            contents: data,
            attributes: [.posixPermissions: 0o600, .ownerAccountID: 0]
        )
    }

    private func isOwnedByRoot(_ path: String) -> Bool {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: path),
            let owner = attributes[.ownerAccountID] as? NSNumber
        else { return false }

        return owner.uint32Value == 0
    }

    /// Make sure the state directory exists and that only root can write to it.
    ///
    /// Checked on every read and write rather than only at creation: the protection that matters is on
    /// the directory, because deleting or replacing a file needs write permission there and not on the
    /// file itself. Running as root, we can repair it rather than just complain.
    private func prepareStateDirectory() {
        let attributes: [FileAttributeKey: Any] = [.posixPermissions: 0o700, .ownerAccountID: 0, .groupOwnerAccountID: 0]

        guard FileManager.default.fileExists(atPath: Self.stateDirectory) else {
            try? FileManager.default.createDirectory(
                atPath: Self.stateDirectory,
                withIntermediateDirectories: true,
                attributes: attributes
            )
            return
        }

        guard let current = try? FileManager.default.attributesOfItem(atPath: Self.stateDirectory) else { return }

        let owner = (current[.ownerAccountID] as? NSNumber)?.uint32Value ?? 0
        let permissions = (current[.posixPermissions] as? NSNumber)?.int16Value ?? 0

        if owner != 0 || (permissions & 0o077) != 0 {
            Logger.shared.logError("Repairing permissions on \(Self.stateDirectory)")
            try? FileManager.default.setAttributes(attributes, ofItemAtPath: Self.stateDirectory)
        }
    }

    // MARK: Audit log

    /// Flatten text that came from outside before it is written to the audit log.
    ///
    /// The reason is typed by the user. One line per event is the only structure this log has, so a
    /// reason containing a newline would let anyone with the elevation dialog write entries of their
    /// choosing into a root-owned record — including lines that look like demotions that never
    /// happened. Control characters go, and the length is bounded so the log cannot be inflated
    /// without limit.
    private static func sanitizedForAuditLog(_ text: String) -> String {
        let flattened = text.unicodeScalars
            .map { CharacterSet.controlCharacters.contains($0) ? " " : Character($0) }
            .reduce(into: "") { $0.append($1) }
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard flattened.count > maximumReasonLength else { return flattened }

        return String(flattened.prefix(maximumReasonLength)) + "…(truncated)"
    }

    /// Append to the root-owned record of who elevated and why.
    ///
    /// The app also writes a reason log under the user's Application Support folder, but the user can edit
    /// that one, so it is a convenience rather than a record. This one the user cannot touch.
    private func appendAuditLine(_ line: String) {
        prepareStateDirectory()

        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(Self.sanitizedForAuditLog(line))\n"
        guard let data = stamped.data(using: .utf8) else { return }

        if let handle = FileHandle(forWritingAtPath: Self.auditLogPath) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            FileManager.default.createFile(
                atPath: Self.auditLogPath,
                contents: data,
                attributes: [.posixPermissions: 0o600, .ownerAccountID: 0]
            )
        }
    }

    // MARK: Operations

    func elevate(userName: String, reason: String, maximumMinutes: Int) async throws -> String {
        let output = try await ExecutionService.run(
            "/usr/sbin/dseditgroup",
            ["-o", "edit", "-a", userName, "-t", "user", "admin"]
        )

        let minutes = max(1, maximumMinutes)
        let deadline = Date().addingTimeInterval(TimeInterval(minutes * 60))

        // Taken after the grant, so the user we just elevated is part of the baseline rather than
        // the first thing the watchdog objects to.
        let baseline = await currentAdminSnapshot()

        queue.sync {
            var elevations = loadElevations().filter { $0.userName != userName && $0.isActive }
            elevations.append(Elevation(userName: userName, deadline: deadline, baseline: baseline))

            saveElevations(elevations)
            scheduleTimerLocked(for: deadline, userName: userName)
            startWatchdogLocked()
        }

        let trimmedReason = Self.sanitizedForAuditLog(reason)
        appendAuditLine("elevated \(userName) for \(minutes)m reason=\(trimmedReason.isEmpty ? "(none)" : trimmedReason)")
        Logger.shared.logWarning("Elevated \(userName) until \(deadline)")

        return output
    }

    func demote(userName: String) async throws -> String {
        // One last look before the window closes. The watchdog stops when the last window does, so
        // without this a grant made between the final tick and the deadline would never be seen.
        // Named explicitly: by the time the timer fires this user's deadline has passed, so they no
        // longer look active, and the sweep would otherwise skip the very window it is closing.
        await checkForNewAdministrators(closingUser: userName)

        let output = try await ExecutionService.run(
            "/usr/sbin/dseditgroup",
            ["-o", "edit", "-d", userName, "-t", "user", "admin"]
        )

        queue.sync {
            let remaining = loadElevations().filter { $0.userName != userName && $0.isActive }
            saveElevations(remaining)

            cancelTimerLocked(for: userName)

            // Other users may still be elevated; the watchdog belongs to the set, not to one window.
            if remaining.isEmpty {
                cancelWatchdogLocked()
            }
        }

        appendAuditLine("demoted \(userName)")
        Logger.shared.logWarning("Demoted \(userName)")

        return output
    }

    func timeRemaining(userName: String) -> Double {
        queue.sync {
            guard let elevation = loadElevations().first(where: { $0.userName == userName }) else { return 0 }
            return max(0, elevation.deadline.timeIntervalSinceNow)
        }
    }

    /// Re-arm timers at launch, demote anything already overdue, and reconcile the admin group.
    ///
    /// The state file is the fast path, not the authority. An attacker with root can delete it and
    /// restart us, and then nothing in it says a demotion was ever owed — which is why a missing state
    /// file must not mean "nothing to do" wherever we have something better to go on.
    func reconcileOnLaunch() {
        let configuredAdmins = HelperPreferences.permanentAdmins
            .map { $0.sorted().joined(separator: ", ") } ?? "(not configured)"
        Logger.shared.logWarning("Helper starting: EnforceAdminAllowlist=\(HelperPreferences.enforceAdminAllowlist), PermanentAdmins=\(configuredAdmins)")

        let elevations = queue.sync { loadElevations() }

        for elevation in elevations {
            if elevation.isActive {
                Logger.shared.logWarning("Restoring demotion timer for \(elevation.userName), due \(elevation.deadline)")
                queue.sync { scheduleTimerLocked(for: elevation.deadline, userName: elevation.userName) }
            } else {
                let overrun = Date().timeIntervalSince(elevation.deadline)
                Logger.shared.logWarning("Elevation for \(elevation.userName) expired \(Int(overrun))s ago while the helper was not running")
                appendAuditLine("overdue demotion for \(elevation.userName), \(Int(overrun))s past the deadline")
                queue.sync { demoteInBackground(userName: elevation.userName) }
            }
        }

        if elevations.contains(where: { $0.isActive }) {
            queue.sync { startWatchdogLocked() }
        }

        // Started whatever the policy currently says, so that a profile removed and then re-asserted
        // by the MDM takes effect without waiting for a restart.
        queue.sync { startReconcilerLocked() }

        Task { await reconcileAdmins() }
    }

    private func startReconcilerLocked() {
        reconciler?.cancel()

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + Self.reconcileInterval, repeating: Self.reconcileInterval)
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Task { await self.reconcileAdmins() }
        }
        source.resume()

        reconciler = source
    }

    /// Compare the admin group against the allowlist and take back what it does not account for.
    ///
    /// The policy is re-read every time rather than cached, so removing the profile only suspends
    /// enforcement for as long as it is actually missing.
    private func reconcileAdmins() async {
        guard HelperPreferences.enforceAdminAllowlist else { return }

        // Enforcing with no list at all would demote every administrator on the Mac, which is far
        // more likely to be a half-finished profile than somebody's intent. An explicitly empty list
        // is honored; a missing one is refused.
        guard var accountedFor = HelperPreferences.permanentAdmins else {
            Logger.shared.logError("EnforceAdminAllowlist is set but PermanentAdmins is not configured. Refusing to enforce: set PermanentAdmins, using an empty array if no account should be permanently an administrator.")
            return
        }

        // A live elevation window is the one legitimate reason to hold administrator rights without
        // appearing in the allowlist.
        for elevation in queue.sync(execute: { loadElevations() }) where elevation.isActive {
            accountedFor.insert(elevation.userName)
        }

        await demoteUnaccountedAdmins(accountedFor: accountedFor)
    }

    /// Take administrator rights from accounts that policy does not account for.
    ///
    /// This is what makes deleting the state file the losing move rather than the winning one: with no
    /// record of a grant, an elevated user is simply someone holding rights the allowlist does not
    /// explain, and loses them at the next reconciliation.
    private func demoteUnaccountedAdmins(accountedFor: Set<String>) async {
        let current = await currentAdminSnapshot()

        // An empty read means dscl failed. Demoting every administrator on the strength of a failed
        // command is not a risk worth taking.
        guard !current.isEmpty else {
            Logger.shared.logError("Skipping allowlist enforcement: unable to read the admin group")
            return
        }

        var permitted = accountedFor
        permitted.insert("root")

        // Membership by UUID grants administrator rights exactly as a short name does, so an entry
        // added that way has to be reconciled too. Resolving first means an allowlisted account added
        // by UUID is recognized rather than stripped.
        let (unexpectedNames, unexpectedUUIDs, unresolvedUUIDs) = await unaccountedMembers(in: current, permitted: permitted)

        // Reported, never removed. This runs unattended every few minutes with no notion of when an
        // entry appeared, so a failed lookup is not grounds for taking administrator rights away —
        // the entry may predate this Mac's current directory configuration, or the account behind it
        // may simply not be visible from here. Anything that appears *during* an elevation is caught
        // by the watchdog instead, which knows what the group looked like beforehand.
        if !unresolvedUUIDs.isEmpty {
            Logger.shared.logWarning("Admin group contains \(unresolvedUUIDs.count) member(s) with no resolvable account, left alone: \(unresolvedUUIDs.sorted().joined(separator: ", "))")
        }

        guard !unexpectedNames.isEmpty || !unexpectedUUIDs.isEmpty else { return }

        for name in unexpectedNames.sorted() {
            // Never touch uid 0, whatever the account is called.
            if let entry = getpwnam(name), entry.pointee.pw_uid == 0 {
                Logger.shared.logWarning("Not demoting \(name): uid 0")
                continue
            }

            do {
                _ = try await ExecutionService.run("/usr/sbin/dseditgroup", ["-o", "edit", "-d", name, "-t", "user", "admin"])
                Logger.shared.logWarning("Demoted \(name): not in PermanentAdmins and no active elevation")
                appendAuditLine("allowlist enforcement demoted \(name)")
            } catch {
                Logger.shared.logError("Failed to demote \(name): \(error.localizedDescription)")
            }
        }

        for uuid in unexpectedUUIDs.sorted() {
            _ = try? await ExecutionService.run("/usr/bin/dscl", [".", "-delete", "/Groups/admin", "GroupMembers", uuid])
            Logger.shared.logWarning("Removed admin group member \(uuid): no account, and not accounted for")
            appendAuditLine("allowlist enforcement removed admin uuid \(uuid)")
        }
    }

    /// Split admin group membership into what policy accounts for and what it does not, resolving
    /// UUID entries to accounts so both forms are judged by the same list.
    ///
    /// Unresolvable UUIDs are reported separately rather than lumped in with the rest, because the two
    /// callers should treat them differently. A UUID with no account behind it is not evidence of
    /// anything: it may be an entry left over from a deleted account, or an identity this Mac cannot
    /// see. Removing it is only safe where something else establishes that it appeared just now.
    private func unaccountedMembers(
        in snapshot: AdminSnapshot,
        permitted: Set<String>
    ) async -> (names: Set<String>, uuids: Set<String>, unresolved: Set<String>) {
        var namesByUUID: [String: String] = [:]
        var unresolved: Set<String> = []

        for uuid in snapshot.uuids {
            if let name = await accountName(forGeneratedUID: uuid) {
                namesByUUID[uuid] = name
            } else {
                unresolved.insert(uuid)
            }
        }

        let names = snapshot.names.union(namesByUUID.values).subtracting(permitted)

        // A UUID whose account is permitted stays.
        let uuids = Set(namesByUUID.filter { !permitted.contains($0.value) }.keys)

        return (names, uuids, unresolved)
    }

    // MARK: Timers

    private func scheduleTimerLocked(for deadline: Date, userName: String) {
        cancelTimerLocked(for: userName)

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now() + max(0, deadline.timeIntervalSinceNow))
        source.setEventHandler { [weak self] in
            guard let self else { return }
            Logger.shared.logWarning("Elevation expired for \(userName)")
            self.demoteInBackground(userName: userName)
        }
        source.resume()

        timers[userName] = source
    }

    private func cancelTimerLocked(for userName: String) {
        timers[userName]?.cancel()
        timers[userName] = nil
    }

    private func demoteInBackground(userName: String) {
        Task {
            do {
                _ = try await self.demote(userName: userName)
            } catch {
                Logger.shared.logError("Failed to demote \(userName): \(error.localizedDescription)")
            }
        }
    }

    // MARK: Watchdog

    /// Watch the `admin` group for as long as any window is open.
    ///
    /// Demoting one account at the end does nothing about a *second* administrator created during the
    /// window, which outlives the elevation entirely. Those rights are taken back as soon as they
    /// appear, and taken back again if they reappear, since the baselines do not move.
    ///
    /// Elevated users keep their own rights until their timers run out. They were granted for a
    /// reason and the granted window is not what went wrong; the extra account is, and that is what
    /// gets undone.
    ///
    /// This is containment, not prevention. Someone with root for a few seconds has other ways to
    /// persist — a launch daemon, a sudoers drop-in, enabling the root account — none of which show up
    /// in a group. What this does is close the cheapest and most common one, and make it noisy.
    private func startWatchdogLocked() {
        guard watchdog == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: Self.watchdogInterval)
        source.setEventHandler { [weak self] in
            guard let self, !self.isCheckingAdmins else { return }
            self.isCheckingAdmins = true

            Task {
                await self.checkForNewAdministrators()
                self.queue.async { self.isCheckingAdmins = false }
            }
        }
        source.resume()

        watchdog = source
    }

    private func cancelWatchdogLocked() {
        watchdog?.cancel()
        watchdog = nil
    }

    /// Look for administrator rights that appeared during an open window.
    ///
    /// - Parameter closingUser: the user whose window is being closed right now, if any. Their
    ///   deadline has just passed, so they no longer count as active — but this sweep exists
    ///   precisely to catch a grant made in the last moments before a window ends, and skipping it
    ///   because the clock ticked over would leave the normal expiry path unswept.
    private func checkForNewAdministrators(closingUser: String? = nil) async {
        let allElevations = queue.sync { loadElevations() }

        let relevant = allElevations.filter { elevation in
            elevation.isActive || elevation.userName == closingUser
        }
        guard !relevant.isEmpty else { return }

        let current = await currentAdminSnapshot()

        // An empty read means dscl failed; treat it as no information rather than as everyone leaving
        guard !current.isEmpty else { return }

        // Anyone who was an administrator when any open window started, plus accounts an
        // administrator has declared as expected — for management accounts an MDM may legitimately
        // add while somebody happens to be elevated.
        var permitted = Set(
            HelperPreferences.object(forKey: "ElevationAllowedAdmins", forUser: nil) as? [String] ?? []
        )
        permitted.insert("root")

        // Every user we have granted rights to, whether or not their window is still open. One whose
        // deadline has passed is waiting to be demoted, not an intruder — and without this, a user
        // whose window ends while somebody else is still elevated gets written to the audit log as an
        // unexplained administrator. That entry would be false, and this log is the record.
        for elevation in allElevations {
            permitted.insert(elevation.userName)
        }

        for elevation in relevant {
            permitted.formUnion(elevation.baseline.names)
        }

        var baselineUUIDs: Set<String> = []
        for elevation in relevant {
            baselineUUIDs.formUnion(elevation.baseline.uuids)
        }

        let candidates = AdminSnapshot(
            names: current.names,
            uuids: current.uuids.subtracting(baselineUUIDs)
        )

        // Unresolvable UUIDs are revoked here, unlike in the standing reconciler. The baseline was
        // subtracted above, so everything left appeared after this window opened — which is the
        // evidence the reconciler lacks, and what makes removing an unidentifiable entry reasonable.
        let (namesToRevoke, resolvedUUIDs, unresolvedUUIDs) = await unaccountedMembers(in: candidates, permitted: permitted)
        let uuidsToRevoke = resolvedUUIDs.union(unresolvedUUIDs)

        guard !namesToRevoke.isEmpty || !uuidsToRevoke.isEmpty else { return }

        let describedUsers = relevant.map(\.userName).sorted().joined(separator: ", ")
        let describedNames = namesToRevoke.sorted().joined(separator: ", ")

        Logger.shared.logError("New administrator(s) appeared during elevation of [\(describedUsers)]: \(describedNames.isEmpty ? uuidsToRevoke.sorted().joined(separator: ", ") : describedNames)")
        appendAuditLine("admin granted during elevation of [\(describedUsers)] to [\(describedNames)] uuids=[\(uuidsToRevoke.sorted().joined(separator: ", "))]")

        for name in namesToRevoke.sorted() {
            if let entry = getpwnam(name), entry.pointee.pw_uid == 0 { continue }

            do {
                _ = try await ExecutionService.run("/usr/sbin/dseditgroup", ["-o", "edit", "-d", name, "-t", "user", "admin"])
                appendAuditLine("revoked admin from \(name)")
            } catch {
                Logger.shared.logError("Failed to revoke admin from \(name): \(error.localizedDescription)")
            }
        }

        // Removing the account by name normally clears its UUID entry too, so this is the fallback for
        // a UUID with no account behind it and a second pass for the rest.
        for uuid in uuidsToRevoke.sorted() {
            _ = try? await ExecutionService.run("/usr/bin/dscl", [".", "-delete", "/Groups/admin", "GroupMembers", uuid])
        }
    }

    /// Resolve a `GeneratedUID` back to a short account name, or `nil` when no account has it.
    private func accountName(forGeneratedUID uuid: String) async -> String? {
        guard
            let output = try? await ExecutionService.run("/usr/bin/dscl", [".", "-search", "/Users", "GeneratedUID", uuid]),
            let firstLine = output.split(separator: "\n").first,
            let name = firstLine.split(whereSeparator: \.isWhitespace).first
        else { return nil }

        return String(name)
    }

    /// Read the `admin` group's membership, by name and by UUID.
    private func currentAdminSnapshot() async -> AdminSnapshot {
        guard let output = try? await ExecutionService.run(
            "/usr/bin/dscl", [".", "-read", "/Groups/admin", "GroupMembership", "GroupMembers"]
        ) else {
            Logger.shared.logError("Unable to read the admin group")
            return AdminSnapshot()
        }

        return Self.parseAdminSnapshot(output)
    }

    /// dscl prints `Key: a b c`, and wraps long values onto following indented lines, so each key's
    /// value runs until the next line that starts a new key.
    static func parseAdminSnapshot(_ output: String) -> AdminSnapshot {
        var snapshot = AdminSnapshot()
        var currentKey: String?

        for line in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let isContinuation = line.hasPrefix(" ") || line.hasPrefix("\t")
            var values = Substring(line)

            if !isContinuation, let colon = line.firstIndex(of: ":") {
                currentKey = String(line[line.startIndex..<colon])
                values = line[line.index(after: colon)...]
            } else if !isContinuation {
                continue
            }

            let tokens = values.split(whereSeparator: \.isWhitespace).map(String.init)

            switch currentKey {
            case "GroupMembership": snapshot.names.formUnion(tokens)
            case "GroupMembers": snapshot.uuids.formUnion(tokens)
            default: break
            }
        }

        return snapshot
    }
}

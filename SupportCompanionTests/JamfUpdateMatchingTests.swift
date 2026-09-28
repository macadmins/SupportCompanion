//
//  JamfUpdateMatchingTests.swift
//  SupportCompanionTests
//

import Foundation
import Testing
@testable import SupportCompanion

@Suite("Jamf update matching")
struct JamfUpdateMatchingTests {

    // Dates from the Self Service store that produced the regression: the Zoom patch became available
    // on 2026-09-24 with a deadline a week later, and the installed policy was last touched in 2025.
    private let now = Date(timeIntervalSinceReferenceDate: 811_984_000)      // 2026-09-25
    private let available = Date(timeIntervalSinceReferenceDate: 811_937_502) // 2026-09-24
    private let deadline = Date(timeIntervalSinceReferenceDate: 812_542_302)  // 2026-10-01
    private let longAgo = Date(timeIntervalSinceReferenceDate: 784_713_567)   // 2025-11-13

    private func policy(
        _ name: String,
        version: String? = nil,
        installStatus: Int? = 4,
        installedOrUpdated: Date? = nil
    ) -> Policy {
        Policy(
            id: 1,
            name: name,
            policyVersion: version,
            installedOrUpdated: installedOrUpdated,
            installStatus: installStatus,
            iconUrl: nil,
            postInstallText: nil
        )
    }

    private func patch(_ name: String, version: String, deadline: Date? = nil) -> Patch {
        Patch(
            id: 1,
            name: name,
            version: version,
            availableDate: available,
            deadlineDate: deadline,
            buttonText: "Update",
            installStatus: 0
        )
    }

    private func updates(
        _ policies: [Policy],
        _ patches: [Patch],
        installed: [String]
    ) async -> [PendingJamfUpdate] {
        await computeUpdates(policies: policies, patches: patches, now: now, installedApps: installed).0
    }

    // MARK: - The regression

    @Test("Reports a patch whose installed app sits under a different policy name")
    func prefersTheInstalledPolicy() async {
        // Exactly what Jamf served: the patch title exists as its own uninstalled policy, while the
        // app that is actually on the Mac is listed under "zoom.us".
        let result = await updates(
            [
                policy("Zoom Client for Meetings", version: "7.2.2 (88465)", installStatus: 0),
                policy("zoom.us", version: "7.0.5 (81138)", installStatus: 4, installedOrUpdated: longAgo),
            ],
            [patch("Zoom Client for Meetings", version: "7.2.2 (88465)", deadline: deadline)],
            installed: ["zoom.us"]
        )

        #expect(result.count == 1)
        #expect(result.first?.name == "Zoom Client for Meetings")
        #expect(result.first?.policyName == "zoom.us")
    }

    @Test("An exact name match still wins when that policy's app is installed")
    func exactMatchPreferred() async {
        let result = await updates(
            [
                policy("Figma", version: "126.8.16", installedOrUpdated: longAgo),
                policy("Figma Agent", version: "1.0", installedOrUpdated: longAgo),
            ],
            [patch("Figma", version: "127.0", deadline: deadline)],
            installed: ["Figma", "Figma Agent"]
        )

        #expect(result.first?.policyName == "Figma")
    }

    // MARK: - Installed, according to the Mac rather than Jamf

    @Test("Reports a patch for an app Jamf does not think it installed")
    func installStatusZeroButOnDisk() async {
        // Apparency: present in /Applications, but its policy reports installstatus 0.
        let result = await updates(
            [policy("Apparency", version: "3.1", installStatus: 0)],
            [patch("Mothers Ruin Apparency", version: "3.2", deadline: deadline)],
            installed: ["Apparency"]
        )

        #expect(result.count == 1)
        #expect(result.first?.policyName == "Apparency")
    }

    @Test("Says nothing about an app Jamf believes is installed but the Mac does not have")
    func installStatusFourButAbsent() async {
        // Brave: the policy reports installstatus 4 and the bundle is gone. An "update" here would
        // really be a fresh install of something nobody asked for.
        let result = await updates(
            [policy("Brave Browser", version: "154.1.96.59", installedOrUpdated: longAgo)],
            [patch("Brave Browser", version: "155.0", deadline: deadline)],
            installed: ["Figma", "zoom.us"]
        )

        #expect(result.isEmpty)
    }

    @Test("Says nothing about an app that is neither installed nor claimed to be")
    func neitherSourceSaysInstalled() async {
        let result = await updates(
            [policy("GIMP", version: "3.0", installStatus: 0)],
            [patch("GIMP", version: "3.1", deadline: deadline)],
            installed: ["Figma"]
        )

        #expect(result.isEmpty)
    }

    @Test("Falls back to Jamf's record when the Mac cannot be read")
    func emptyIndexFallsBackToInstallStatus() async {
        // An empty index means the directory scan failed, not that the Mac has no applications, so
        // dropping every patch would be the wrong reading of it.
        let policies = [policy("Brave Browser", version: "154.1.96.59", installedOrUpdated: longAgo)]
        let patches = [patch("Brave Browser", version: "155.0", deadline: deadline)]

        #expect(await updates(policies, patches, installed: []).count == 1)
        #expect(await updates(policies.map {
            policy($0.name, version: $0.policyVersion, installStatus: 0)
        }, patches, installed: []).isEmpty)
    }

    // MARK: - Counting

    @Test("An installed app with no patch counts as up to date")
    func upToDateCount() async {
        let (results, updateCount, upToDateCount) = await computeUpdates(
            policies: [
                policy("zoom.us", version: "7.0.5 (81138)", installedOrUpdated: longAgo),
                policy("Figma", version: "126.8.16", installedOrUpdated: longAgo),
                policy("Brave Browser", version: "154.1", installedOrUpdated: longAgo),
            ],
            patches: [patch("Zoom Client for Meetings", version: "7.2.2 (88465)", deadline: deadline)],
            now: now,
            installedApps: ["zoom.us", "Figma"]
        )

        #expect(results.count == 1)
        #expect(updateCount == 1)
        // Figma is installed and unpatched; Brave is not on the Mac and is counted neither way.
        #expect(upToDateCount == 1)
    }

    // MARK: - Name matching

    @Test("Matches names across Jamf's spellings, and keeps distinct apps apart")
    func nameSimilarityScores() {
        // "client", "for" and "meetings" are stop words, so both sides reduce to "zoom".
        #expect(nameSimilarity("Zoom Client for Meetings", "zoom.us") >= nameMatchThreshold)
        #expect(nameSimilarity("Mothers Ruin Apparency", "Apparency") >= nameMatchThreshold)
        #expect(nameSimilarity("Google Chrome", "Google Chrome") == 1.0)

        #expect(nameSimilarity("Slack", "Zoom") == 0)
        // Nothing usable on one side is not a match, rather than a vacuous one.
        #expect(nameSimilarity("app", "Slack") == 0)

        // Normalizing by the shorter name is what lets "zoom.us" answer for "Zoom Client for
        // Meetings", and the price is that a one-token name matches any superset of it perfectly.
        // Install evidence, not the score, is what keeps these apart.
        #expect(nameSimilarity("Firefox", "Firefox Developer Edition") == 1.0)
    }

    @Test("A one-token name does not steal a patch from the app Jamf installed")
    func supersetNamesSeparatedByEvidence() async {
        let result = await updates(
            [
                policy("Firefox", installStatus: 0),
                policy("Firefox Developer Edition", installedOrUpdated: longAgo),
            ],
            [patch("Firefox Developer Edition", version: "146.0", deadline: deadline)],
            installed: ["Firefox Developer Edition"]
        )

        #expect(result.first?.policyName == "Firefox Developer Edition")
    }

    // MARK: - Pairing an update with the installed app

    @Test("An update names the installed app, so the Apps page can pair them")
    func updateNamesTheInstalledApp() async {
        // The Apps page groups by `installedAppName`, and Self Service lists the installed app as
        // "zoom.us" while the patch is called "Zoom Client for Meetings". Resolving to the listing
        // instead would leave the update unpairable and its card without an Update button.
        let result = await updates(
            [
                policy("Zoom Client for Meetings", version: "7.2.2 (88465)", installStatus: 0),
                policy("zoom.us", version: "7.0.5 (81138)", installedOrUpdated: longAgo),
            ],
            [patch("Zoom Client for Meetings", version: "7.2.2 (88465)", deadline: deadline)],
            installed: ["zoom.us"]
        )

        let update = try? #require(result.first)
        #expect(update?.installedAppName == "zoom.us")
    }

    @Test("A patch with no usable tokens does not match an arbitrary policy")
    func unmatchablePatchName() async {
        let result = await updates(
            [policy("Figma", version: "126.8.16", installedOrUpdated: longAgo)],
            [patch("Update", version: "1.0", deadline: deadline)],
            installed: ["Figma"]
        )

        #expect(result.isEmpty)
    }
}

@Suite("Recently installed Jamf patches")
struct RecentlyInstalledPatchesTests {

    private let now = Date(timeIntervalSinceReferenceDate: 811_984_000)

    private func update(_ patchId: Int, _ name: String, _ version: String) -> PendingJamfUpdate {
        PendingJamfUpdate(
            id: UUID(),
            name: name,
            version: version,
            needsUpdate: true,
            label: .dueNoDeadline,
            details: "",
            showInfoIcon: false,
            dueBy: nil,
            patchId: patchId,
            policyName: name
        )
    }

    @Test("An installed patch stops being offered while the store still lists it")
    func hidesWhatWasJustInstalled() {
        var tracked = RecentlyInstalledPatches()
        let zoom = update(274, "Zoom Client for Meetings", "7.2.2 (88465)")

        #expect(tracked.filtering([zoom], now: now).count == 1) // before installing

        tracked.record(patchId: 274, version: "7.2.2 (88465)", at: now)
        #expect(tracked.filtering([zoom], now: now).isEmpty) // the store has not caught up yet
    }

    @Test("Forgets the patch once the store drops it")
    func forgetsWhenStoreCatchesUp() {
        var tracked = RecentlyInstalledPatches()
        tracked.record(patchId: 274, version: "7.2.2 (88465)", at: now)

        // Self Service+ rewrote its store and the patch is gone.
        #expect(tracked.filtering([], now: now).isEmpty)
        #expect(tracked.isEmpty)
    }

    @Test("A newer patch for the same app is still offered")
    func newerVersionIsNotHidden() {
        var tracked = RecentlyInstalledPatches()
        tracked.record(patchId: 274, version: "7.2.2 (88465)", at: now)

        let newer = update(274, "Zoom Client for Meetings", "7.3.0 (90001)")
        #expect(tracked.filtering([newer], now: now).count == 1)
    }

    @Test("Comes back when the store never drops it, rather than hiding for good")
    func reappearsAfterTheTimeout() {
        var tracked = RecentlyInstalledPatches()
        let zoom = update(274, "Zoom Client for Meetings", "7.2.2 (88465)")
        tracked.record(patchId: 274, version: "7.2.2 (88465)", at: now)

        let justBefore = now.addingTimeInterval(RecentlyInstalledPatches.timeout - 1)
        #expect(tracked.filtering([zoom], now: justBefore).isEmpty)

        let after = now.addingTimeInterval(RecentlyInstalledPatches.timeout)
        #expect(tracked.filtering([zoom], now: after).count == 1)
        #expect(tracked.isEmpty) // and it is not hidden again next time either
    }

    @Test("Other apps' updates are untouched")
    func leavesOtherUpdatesAlone() {
        var tracked = RecentlyInstalledPatches()
        tracked.record(patchId: 274, version: "7.2.2 (88465)", at: now)

        let zoom = update(274, "Zoom Client for Meetings", "7.2.2 (88465)")
        let figma = update(99, "Figma", "127.0")

        #expect(tracked.filtering([zoom, figma], now: now).map(\.patchId) == [99])
    }
}

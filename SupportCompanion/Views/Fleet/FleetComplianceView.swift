//
//  FleetComplianceView.swift
//  SupportCompanion
//
//  The Compliance page in Fleet mode: every check Fleet runs on this Mac, and how to fix the failing ones.
//  Hide the page with HiddenCards `FleetPolicies`.
//

import SwiftUI

struct FleetComplianceView: View {
    @Environment(AppStateManager.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPassing = true

    private var manager: FleetDeviceManager { appState.fleetDeviceManager }
    private let passingColumns = [GridItem(.adaptive(minimum: 240), alignment: .leading)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                content
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .task { await manager.refreshIfStale() }
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        let failing = manager.failingPolicies
        let checked = manager.checkedPolicies
        let isFailing = !failing.isEmpty
        let hasCritical = failing.contains { $0.critical == true }
        let tint = isFailing ? (hasCritical ? criticalColor : warningColor) : Color.ScGreen

        HStack(alignment: .center, spacing: 16) {
            Image(systemName: isFailing ? "exclamationmark.shield.fill" : "checkmark.shield.fill")
                .font(.system(size: 34))
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(headline(failing: failing.count, checked: checked.count))
                    .font(.system(size: 19, weight: .semibold))
                if let checkedAt = lastCheckedText {
                    Text(checkedAt)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if let error = manager.refetchError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(warningColor)
            }

            if manager.host != nil {
                FleetRecheckButton(fontSize: 13)
            }
        }
    }

    private func headline(failing: Int, checked: Int) -> String {
        if checked == 0 { return Constants.Fleet.noPolicies }
        if failing == 0 { return String(format: Constants.Fleet.policiesPassing, checked) }
        return String(format: Constants.Fleet.policiesFailing, failing, checked)
    }

    private var lastCheckedText: String? {
        guard manager.host != nil,
              let date = FleetHost.realDate(manager.host?.detailUpdatedAt) else { return nil }
        if manager.isRefetching { return Constants.Actions.refetching }
        return String(format: Constants.Fleet.lastChecked, date.formatted(.relative(presentation: .named)))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch manager.loadState {
        case .idle:
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        case .ssoRequired where manager.policies.isEmpty:
            message(Constants.Fleet.policiesSignIn, systemImage: "person.badge.key")
        case .failed where manager.policies.isEmpty:
            message(Constants.Fleet.policiesUnavailable, systemImage: "exclamationmark.triangle")
        default:
            if manager.checkedPolicies.isEmpty {
                message(Constants.Fleet.noPolicies, systemImage: "checkmark.shield")
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    failingSection
                    passingSection
                }
            }
        }
    }

    /// The reason the page exists, so the fix is visible rather than hidden behind a disclosure — unless
    /// there are enough failures that expanding them all would bury the list.
    @ViewBuilder
    private var failingSection: some View {
        let failing = manager.failingPolicies
        if !failing.isEmpty {
            VStack(spacing: 10) {
                ForEach(failing) { policy in
                    FailingPolicyCard(
                        policy: policy,
                        tint: policy.critical == true ? criticalColor : warningColor,
                        startExpanded: failing.count <= 2
                    )
                }
            }
        }
    }

    /// Reference material once the failures are dealt with, so it stays dense.
    @ViewBuilder
    private var passingSection: some View {
        let passing = manager.passingPolicies
        if !passing.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showPassing.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(showPassing ? 90 : 0))
                        Text(String(format: Constants.Fleet.passingChecks, passing.count))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if showPassing {
                    LazyVGrid(columns: passingColumns, alignment: .leading, spacing: 7) {
                        ForEach(passing) { policy in
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.ScGreen)
                                Text(policy.name)
                                    .lineLimit(2)
                                    .help(policy.description ?? "")
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .isGlass()
                    .cornerRadius(10)
                }
            }
        }
    }

    private func message(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var warningColor: Color { colorScheme == .light ? .orangeLight : .orange }
    private var criticalColor: Color { colorScheme == .light ? .redLight : .red }
}

private struct FailingPolicyCard: View {
    let policy: FleetPolicy
    let tint: Color
    let startExpanded: Bool

    @State private var isExpanded: Bool?
    @Environment(\.colorScheme) private var colorScheme

    /// Long lines are hard to scan, so policy text stops well short of the window's width.
    private static let textWidth: CGFloat = 720

    private var expanded: Bool { isExpanded ?? startExpanded }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(tint)
                    Text(policy.name)
                        .font(.system(size: 15, weight: .semibold))
                    if policy.critical == true {
                        Text(Constants.Fleet.critical)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(tint.opacity(0.18), in: Capsule())
                            .foregroundStyle(tint)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    if let description = trimmed(policy.description) {
                        Text(markdown(description))
                            .foregroundStyle(.secondary)
                    }
                    if let resolution = trimmed(policy.resolution) {
                        DisclosureGroup(
                            Constants.Fleet.howToFix,
                            isExpanded: Binding(get: { expanded }, set: { isExpanded = $0 })
                        ) {
                            Text(markdown(resolution))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 4)
                        }
                    }
                }
                .font(.system(size: 13))
                .frame(maxWidth: Self.textWidth, alignment: .leading)
                .padding(.leading, 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(colorScheme == .light ? 0.06 : 0.11))
        .isGlass()
        .cornerRadius(10)
    }

    private func trimmed(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (value?.isEmpty ?? true) ? nil : value
    }

    /// Fleet descriptions and resolutions are often written in Markdown, e.g. with links.
    private func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

//
//  FleetPoliciesCard.swift
//  SupportCompanion
//
//  Fleet policies that fail on this Mac, with how to fix them. Hide with HiddenCards `FleetPolicies`.
//

import SwiftUI

struct FleetPoliciesCard: View {
    var viewModel: CardGridViewModel
    @Environment(AppStateManager.self) private var appState
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPassing = false
    @State private var passingListHeight: CGFloat = 0

    /// About five rows; longer lists scroll so expanding them barely changes the card's height.
    private static let passingListMaxHeight: CGFloat = 130

    private var manager: FleetDeviceManager { appState.fleetDeviceManager }

    var body: some View {
        if viewModel.isCardVisible(Constants.Cards.fleetPolicies) {
            ScCard(title: Constants.CardTitle.fleetPolicies, titleImageName: "checkmark.shield.fill") {
                VStack(alignment: .leading, spacing: 10) {
                    content
                        .font(.system(size: 14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                    if manager.host != nil {
                        if let error = manager.refetchError {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.system(size: 12))
                                .foregroundStyle(warningColor)
                        }
                        HStack {
                            Spacer()
                            FleetRecheckButton()
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .frame(minHeight: 110)
                .padding(.horizontal)
            }
            .fixedSize(horizontal: false, vertical: false)
            .task {
                await manager.refreshIfStale()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        let failing = manager.failingPolicies
        let checked = manager.checkedPolicies

        switch manager.loadState {
        case .idle:
            ProgressView()
                .frame(maxWidth: .infinity)
        case .ssoRequired where manager.policies.isEmpty:
            Text(Constants.Fleet.policiesSignIn)
                .foregroundStyle(.secondary)
        case .failed where manager.policies.isEmpty:
            Text(Constants.Fleet.policiesUnavailable)
                .foregroundStyle(.secondary)
        default:
            if checked.isEmpty {
                Text(Constants.Fleet.noPolicies)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    if failing.isEmpty {
                        Label(String(format: Constants.Fleet.policiesPassing, checked.count), systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.ScGreen)
                            .fontWeight(.bold)
                    } else {
                        Label(String(format: Constants.Fleet.policiesFailing, failing.count, checked.count), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(warningColor)
                            .fontWeight(.bold)
                        ForEach(failing) { policy in
                            PolicyRow(policy: policy, criticalColor: criticalColor)
                        }
                    }
                    passingList
                }
            }
        }
    }

    /// Collapsed by default, so failing checks stay the focus.
    @ViewBuilder
    private var passingList: some View {
        let passing = manager.passingPolicies
        if !passing.isEmpty {
            DisclosureGroup(isExpanded: $showPassing) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(passing) { policy in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.ScGreen)
                                Text(policy.name)
                                    .lineLimit(2)
                                    .help(policy.description ?? "")
                            }
                        }
                    }
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(GeometryReader { geometry in
                        Color.clear.preference(key: PassingListHeightKey.self, value: geometry.size.height)
                    })
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(height: min(passingListHeight, Self.passingListMaxHeight))
                .onPreferenceChange(PassingListHeightKey.self) { passingListHeight = $0 }
                .padding(.top, 4)
            } label: {
                Text(String(format: Constants.Fleet.passingChecks, passing.count))
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var warningColor: Color { colorScheme == .light ? .orangeLight : .orange }
    private var criticalColor: Color { colorScheme == .light ? .redLight : .red }
}

private struct PolicyRow: View {
    let policy: FleetPolicy
    let criticalColor: Color
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(criticalColor)
                Text(policy.name)
                    .fontWeight(.medium)
                    .lineLimit(2)
                if policy.critical == true {
                    Text(Constants.Fleet.critical)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(criticalColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(criticalColor)
                }
            }
            if let resolution = policy.resolution?.trimmingCharacters(in: .whitespacesAndNewlines), !resolution.isEmpty {
                DisclosureGroup(Constants.Fleet.howToFix, isExpanded: $isExpanded) {
                    Text(Self.markdown(resolution))
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .font(.system(size: 13))
                .padding(.leading, 22)
            }
        }
    }

    /// Fleet resolutions are often written in Markdown, e.g. with links.
    private static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct PassingListHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

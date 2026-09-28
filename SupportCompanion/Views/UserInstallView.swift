//
//  UserInstallView.swift
//  SupportCompanion
//

import SwiftUI

/// What the user sees after opening an installer the administrator may have allowed.
///
/// The decision has already been made by the helper by the time this is drawn, so the window has one
/// job: say what this is, say whether it is allowed, and offer the one action worth taking. The weight
/// follows that — the application's name is the largest thing here, the action is the only filled
/// button, and what was checked sits underneath quietly, there to be believed rather than read.
struct UserInstallView: View {

    let manager: UserInstallManager

    /// Collapsed by default. What is behind it is for whoever writes the profile, not for the person
    /// who just wanted to install something.
    @State private var showDetails = false

    var body: some View {
        VStack(spacing: 0) {
            switch manager.stage {
            case .assessing(let fileName):
                busy(title: Constants.UserInstalls.checking, subtitle: fileName)

            case .allowed(let assessment):
                allowed(assessment)

            case .refused(let assessment):
                refused(assessment)

            case .installing(let assessment):
                busy(
                    title: Constants.UserInstalls.installing,
                    subtitle: assessment.facts.displayName ?? assessment.facts.fileName
                )

            case .installed(let assessment):
                finished(assessment)

            case .failed(let assessment, let message):
                failed(assessment, message: message)

            case nil:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.18), value: manager.stage)
    }

    // MARK: States

    private func busy(title: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
                .padding(.bottom, 4)

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Layout.margin)
    }

    private func allowed(_ assessment: InstallerAssessment) -> some View {
        body(
            assessment,
            status: Status(
                text: Constants.UserInstalls.allowedByAdministrator,
                symbol: "checkmark.seal.fill",
                tint: .green
            ),
            detail: { details(assessment) },
            actions: {
                quiet(Constants.General.cancel) { manager.cancel() }
                primary(Constants.UserInstalls.install) { manager.install() }
            }
        )
    }

    private func refused(_ assessment: InstallerAssessment) -> some View {
        body(
            assessment,
            status: Status(
                text: Constants.UserInstalls.notAllowed,
                symbol: "exclamationmark.triangle.fill",
                tint: .orange
            ),
            detail: {
                VStack(alignment: .leading, spacing: 14) {
                    reasons(assessment.rejectionReasons)

                    if let suggestion = manager.catalogSuggestion(for: assessment.facts) {
                        catalogBanner(suggestion)
                    }

                    DisclosureGroup(isExpanded: $showDetails) {
                        identity(assessment)
                            .padding(.top, 8)
                    } label: {
                        Text(Constants.UserInstalls.details)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .tint(.secondary)
                }
            },
            actions: {
                quiet(Constants.General.close) { manager.cancel() }

                // When the organisation already ships this, that is the answer — not administrator
                // rights, and not a password prompt the user cannot satisfy. The other routes are
                // deliberately not offered alongside it.
                if let suggestion = manager.catalogSuggestion(for: assessment.facts) {
                    primary(Constants.UserInstalls.showInCatalog) { manager.showCatalog(suggestion) }
                } else {
                    switch assessment.fallback {
                    case .elevate:
                        primary(Constants.UserInstalls.elevateInstead) { manager.elevate() }
                    case .installer:
                        primary(Constants.UserInstalls.openInInstaller) { manager.openInInstaller() }
                    case .none:
                        EmptyView()
                    }
                }
            }
        )
    }

    /// The approved copy, offered in place of the download the user went and found.
    private func catalogBanner(_ suggestion: CatalogSuggestion) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.down.app.fill")
                .font(.system(size: 15))
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(Constants.UserInstalls.availableInCatalog)
                    .font(.system(size: 12, weight: .semibold))

                Text(String(format: Constants.UserInstalls.availableInCatalogDetail, suggestion.destinationName))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }

    private func failed(_ assessment: InstallerAssessment?, message: String) -> some View {
        body(
            assessment,
            status: Status(
                text: Constants.UserInstalls.failed,
                symbol: "xmark.octagon.fill",
                tint: .red
            ),
            detail: {
                Text(message)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            },
            actions: {
                quiet(Constants.General.close) { manager.closeWindow() }
                primary(Constants.UserInstalls.openInInstaller) { manager.openInInstaller() }
            }
        )
    }

    private func finished(_ assessment: InstallerAssessment) -> some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
                .padding(.bottom, 16)

            Text(assessment.facts.displayName ?? assessment.facts.fileName)
                .font(.system(size: 17, weight: .semibold))
                .multilineTextAlignment(.center)

            Text(Constants.UserInstalls.installed)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.top, 2)

            Spacer()

            actionBar {
                primary(Constants.General.done) { manager.closeWindow() }
            }
        }
        .padding(Layout.margin)
    }

    // MARK: Shared shape

    private struct Status {
        let text: String
        let symbol: String
        let tint: Color
    }

    /// Header, status, whatever detail the state has, then the actions pinned to the bottom.
    ///
    /// Every state that has something to show shares this, so the title, the status and the buttons sit
    /// in exactly the same place as the window moves between them and nothing jumps.
    private func body<Detail: View, Actions: View>(
        _ assessment: InstallerAssessment?,
        status: Status,
        @ViewBuilder detail: () -> Detail,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let assessment {
                header(assessment)
                    .padding(.bottom, 16)
            }

            statusPill(status)

            // One scroll region for everything between the status and the buttons, sized to the space
            // that is left. A ScrollView has no height of its own, so nesting one next to a view that
            // does means the scrolling one gets squeezed to nothing whenever the window is tight.
            ScrollView {
                detail()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 14)

            actionBar(content: actions)
                .padding(.top, 16)
        }
        .padding(Layout.margin)
    }

    private func header(_ assessment: InstallerAssessment) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: assessment.facts.kind == .diskImage ? "app.dashed" : "shippingbox.fill")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(assessment.facts.displayName ?? assessment.facts.fileName)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle(for: assessment))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func subtitle(for assessment: InstallerAssessment) -> String {
        let kind = assessment.facts.kind == .diskImage
            ? Constants.UserInstalls.kindApplication
            : Constants.UserInstalls.kindPackage

        guard let version = assessment.facts.version else { return kind }

        return "\(Constants.UserInstalls.version) \(version) · \(kind)"
    }

    private func statusPill(_ status: Status) -> some View {
        HStack(spacing: 7) {
            Image(systemName: status.symbol)
                .font(.system(size: 12, weight: .semibold))

            Text(status.text)
                .font(.system(size: 12, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .foregroundStyle(status.tint)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(status.tint.opacity(0.12))
        )
    }

    /// What the helper checked. Reference material, so it is quiet and aligned rather than emphatic.
    private func details(_ assessment: InstallerAssessment) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            if let authority = assessment.facts.authority {
                detailRow(Constants.UserInstalls.developer, authority)
            }

            detailRow(Constants.UserInstalls.verification, verification(assessment))

            if let entry = assessment.matchedEntry {
                detailRow(Constants.UserInstalls.allowedAs, entry)
            }

            // Where it lands. Worth showing even when nothing restricts it: "this browser also writes
            // to /Library/LaunchDaemons" is the kind of thing somebody should be able to notice.
            if !assessment.facts.payloadRoots.isEmpty {
                detailRow(
                    Constants.UserInstalls.installsTo,
                    assessment.facts.payloadRoots.joined(separator: ", ")
                )
            }
        }
    }

    private func verification(_ assessment: InstallerAssessment) -> String {
        if assessment.matchMode == .strict {
            return Constants.UserInstalls.verifiedByDigest
        }

        return assessment.facts.notarized
            ? Constants.UserInstalls.verifiedNotarized
            : Constants.UserInstalls.verifiedSignature
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
                .gridColumnAlignment(.leading)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
                .help(value)
        }
    }

    private func reasons(_ reasons: [String]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(reasons, id: \.self) { reason in
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("•")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)

                    Text(reason)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Everything an administrator needs to write an entry for this installer, in one selectable block.
    ///
    /// A refusal is a dead end otherwise: the person looking at it either has to write the profile
    /// entry or has to send someone the details, and making them transcribe a digest off a screenshot
    /// turns a five-second fix into a ticket.
    private func identity(_ assessment: InstallerAssessment) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            if let authority = assessment.facts.authority {
                identityRow(Constants.UserInstalls.developer, authority, monospaced: false)
            }

            if let identifier = assessment.facts.identifiers.first {
                identityRow(Constants.UserInstalls.identifier, identifier, monospaced: true)
            }

            identityRow(
                "\(Constants.UserInstalls.fingerprint) \(assessment.facts.fileName)",
                assessment.facts.sha256,
                monospaced: true
            )

            if let leaf = assessment.facts.leafCertificateSHA256 {
                identityRow(Constants.UserInstalls.certificate, leaf, monospaced: true)
            }

            // Where it would have installed. An administrator reading a refusal is deciding whether
            // to allow this, and that decision is about what the installer does — not only about who
            // signed it.
            if !assessment.facts.payloadRoots.isEmpty {
                identityRow(
                    Constants.UserInstalls.installsTo,
                    assessment.facts.payloadRoots.joined(separator: "\n"),
                    monospaced: true,
                    lineLimit: 6
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func identityRow(_ label: String, _ value: String, monospaced: Bool, lineLimit: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 10, design: monospaced ? .monospaced : .default))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(lineLimit)
                .truncationMode(.middle)
                .help(value)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Actions

    /// The buttons, right aligned on one baseline with room for the hover effect to grow into.
    private func actionBar<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 0)
            content()
        }
        // ScButton scales to 1.1 on hover; without this it clips against the window edge.
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    /// The one action worth taking, in the organisation's accent colour.
    ///
    /// No `maxWidth`: ScButton applies it as a hard frame, so a label longer than the number guessed
    /// at the call site wraps onto a second line inside the button. Letting it hug its own text is
    /// both tidier and one less number to get wrong when a string is translated.
    private func primary(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        ScButton(title, fontSize: 13) {
            await MainActor.run { action() }
        }
    }

    /// The way out. Deliberately unfilled: two accent-coloured buttons side by side give the user no
    /// clue which one the window is actually for.
    private func quiet(_ title: String, action: @escaping @MainActor () -> Void) -> some View {
        Button {
            action()
        } label: {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                // 16pt vertical to match ScButton's plain `.padding()`, so the two sit on one
                // baseline at the same height. This is what made the row look ragged.
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.07))
                )
        }
        .buttonStyle(.plain)
    }

    private enum Layout {
        static let margin: CGFloat = 26
    }
}

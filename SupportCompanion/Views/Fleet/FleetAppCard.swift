//
//  FleetAppCard.swift
//  SupportCompanion
//

import SwiftUI

struct FleetAppCard: View {
    let title: FleetSoftwareTitle
    /// Outlines the card, for apps IT recommends.
    var highlighted = false

    @State private var icon: NSImage?
    @State private var confirmingUninstall = false
    @State private var showingDetails = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppStateManager.self) private var appState

    private var manager: FleetSoftwareManager { appState.fleetSoftwareManager }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                iconView
                VStack(alignment: .leading, spacing: 4) {
                    Text(title.title)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(2)
                    statusBadge
                }
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let installed = installedVersion {
                    versionRow(Constants.Fleet.version, installed)
                }
                if let available = title.availableVersion, available != installedVersion {
                    versionRow(Constants.Fleet.latestVersion, available)
                }
            }
            .font(.system(size: 13))

            actions
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .isGlass()
        .cornerRadius(10)
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(accentColor.opacity(0.7), lineWidth: 1.5)
            }
        }
        .shadow(radius: 4)
        .padding(5)
        // Also look again once the app is installed, for the icon of the app on disk
        .task(id: "\(title.iconUrl ?? "")|\(title.isInstalled)") {
            icon = FleetIconCache.shared.cachedIcon(for: title)
            icon = await FleetIconCache.shared.icon(for: title) ?? icon
        }
        .confirmationDialog(
            String(format: Constants.Fleet.uninstallConfirmTitle, title.title),
            isPresented: $confirmingUninstall
        ) {
            Button(label(for: .uninstall), role: .destructive) {
                Task { await manager.perform(.uninstall, on: title) }
            }
            Button(Constants.Fleet.cancel, role: .cancel) {}
        } message: {
            Text(Constants.Fleet.uninstallConfirmMessage)
        }
        .sheet(isPresented: $showingDetails) {
            FleetInstallDetailsSheet(title: title)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if manager.isBusy(title) {
                    ProgressView()
                        .controlSize(.small)
                    Text(busyText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if waitingForAppToClose && appIsRunning {
                    FleetActionButton(
                        manager.retryAction(for: title) == .update ? Constants.Fleet.quitAndUpdate : Constants.Fleet.quitAndInstall,
                        tint: accentColor
                    ) {
                        await manager.quitAndRetry(title)
                    }
                } else if let action = buttonAction {
                    FleetActionButton(label(for: action), tint: accentColor) {
                        await manager.perform(action, on: title)
                    }
                }
                if title.hasFailed && !manager.isBusy(title) {
                    Button(Constants.Fleet.details) { showingDetails = true }
                        .buttonStyle(.link)
                }
                Spacer(minLength: 0)
                if (canReinstall || title.canUninstall) && !manager.isBusy(title) {
                    Menu {
                        if canReinstall && buttonAction != .reinstall {
                            Button(label(for: .reinstall)) {
                                Task { await manager.perform(.reinstall, on: title) }
                            }
                        }
                        if title.canUninstall {
                            Button(label(for: .uninstall), role: .destructive) {
                                confirmingUninstall = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .menuStyle(.borderlessButton)
                    .menuIndicator(.hidden)
                    .fixedSize()
                    .help(Constants.Fleet.moreActions)
                }
            }
            if waitingForAppToClose && !manager.isBusy(title) && manager.actionErrors[title.id] == nil {
                Label(
                    String(format: appIsRunning ? Constants.Fleet.appOpenMessage : Constants.Fleet.appClosedMessage, title.title),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }
            if let error = manager.actionErrors[title.id] {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(colorScheme == .light ? Color.orangeLight : .orange)
                    .lineLimit(2)
            }
        }
    }

    /// The main button's action: install or update, or reinstall to retry a failed install.
    private var buttonAction: FleetSoftwareTitle.Action? {
        guard !manager.isBusy(title), title.installer != nil else { return nil }
        if manager.hasUpdate(title) { return .update }
        if !title.isInstalled { return .install }
        return title.status == .failedInstall ? .reinstall : nil
    }

    private var waitingForAppToClose: Bool {
        manager.isWaitingForAppToClose(title)
    }

    private var appIsRunning: Bool {
        FleetRunningApps.shared.isRunning(title)
    }

    private var canReinstall: Bool {
        title.isInstalled && title.installer != nil && !manager.hasUpdate(title)
    }

    /// Includes a version Fleet just installed that its inventory doesn't show yet.
    private var installedVersion: String? {
        manager.installedVersionsAwaitingInventory[title.id] ?? title.installedVersion
    }

    private var accentColor: Color {
        Color(NSColor(hex: appState.preferences.branding.accentColor ?? "") ?? .controlAccentColor)
    }

    private var busyText: String {
        if manager.runningActions[title.id] == .uninstall || title.status == .pendingUninstall {
            return Constants.Fleet.uninstalling
        }
        return Constants.Fleet.installing
    }

    private func label(for action: FleetSoftwareTitle.Action) -> String {
        FleetButtonLabels.current.label(for: title, action: action)
    }

    @ViewBuilder
    private var iconView: some View {
        if let icon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 44, height: 44)
        } else {
            FleetPlaceholderIcon(name: title.title)
                .frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        if let (text, color) = status {
            Text(text)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color.opacity(0.18), in: Capsule())
                .foregroundStyle(color)
        }
    }

    /// Only states worth calling out: the section the card sits in already says installed or available.
    private var status: (String, Color)? {
        if manager.isBusy(title) {
            return (busyText, .blue)
        }
        switch title.status {
        case .pendingInstall:
            return (Constants.Fleet.installing, .blue)
        case .pendingUninstall:
            return (Constants.Fleet.uninstalling, .blue)
        case .failedInstall where waitingForAppToClose:
            return (Constants.Fleet.waitingForAppToClose, colorScheme == .light ? .orangeLight : .orange)
        case .failedInstall:
            return (Constants.Fleet.installFailed, colorScheme == .light ? .redLight : .red)
        case .failedUninstall:
            return (Constants.Fleet.uninstallFailed, colorScheme == .light ? .redLight : .red)
        default:
            if manager.hasUpdate(title) {
                return (Constants.Fleet.updateAvailable, colorScheme == .light ? .orangeLight : .orange)
            }
            return nil
        }
    }

    private func versionRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }
}

/// A tinted capsule rather than the filled `ScButton`: a catalog shows many of these at once, and the apps
/// should carry more weight than a grid of identical solid buttons.
private struct FleetActionButton: View {
    let title: String
    let tint: Color
    let action: () async -> Void

    @State private var isHovered = false
    @State private var isRunning = false

    init(_ title: String, tint: Color, action: @escaping () async -> Void) {
        self.title = title
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            guard !isRunning else { return }
            Task {
                isRunning = true
                await action()
                isRunning = false
            }
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(isHovered ? tint : tint.opacity(0.18), in: Capsule())
                .foregroundStyle(isHovered ? Color.white : tint)
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
    }
}

/// Shown for apps without an icon: the app's initial on a colour picked from its name, so each app keeps its colour.
struct FleetPlaceholderIcon: View {
    let name: String

    private static let palette: [Color] = [.blue, .indigo, .purple, .pink, .red, .orange, .teal, .green, .mint, .cyan]

    var body: some View {
        let color = Self.color(for: name)
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [color.opacity(0.95), color.opacity(0.65)], startPoint: .top, endPoint: .bottom))
            .overlay {
                Text(initial)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(2)
    }

    private var initial: String {
        name.first(where: { $0.isLetter || $0.isNumber }).map { String($0).uppercased() } ?? "?"
    }

    /// Stable across launches, unlike `hashValue`.
    private static func color(for name: String) -> Color {
        let sum = name.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return palette[sum % palette.count]
    }
}

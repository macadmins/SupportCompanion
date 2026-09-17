//
//  FleetAppsView.swift
//  SupportCompanion
//
//  The Apps page in Fleet mode: Fleet's self-service catalog for this Mac.
//

import SwiftUI

struct FleetAppsView: View {
    @Environment(AppStateManager.self) private var appState
    @State private var searchText = ""
    @State private var selectedCategory: String?
    /// Collapsed section ids, separated by commas; remembered per user.
    @AppStorage("FleetCollapsedSections") private var collapsedSections = ""

    private var manager: FleetSoftwareManager { appState.fleetSoftwareManager }
    private let columns = [GridItem(.adaptive(minimum: 260), alignment: .top)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .onAppear { manager.startMonitoring() }
        .onDisappear { manager.stopMonitoring() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField(Constants.Fleet.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                if case .failed(let message) = manager.loadState, !manager.titles.isEmpty {
                    Label(Constants.Fleet.couldNotRefresh, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .help(message)
                }
            }
            .padding(8)
            .isGlass()
            .cornerRadius(8)

            if !visibleCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        categoryChip(nil, label: Constants.Fleet.allCategories)
                        ForEach(visibleCategories, id: \.self) { category in
                            categoryChip(category, label: category)
                        }
                    }
                }
            }
        }
    }

    private func categoryChip(_ category: String?, label: String) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
        } label: {
            Text(label)
                .font(.callout)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Categories that at least one title uses, in the order Fleet returns them.
    private var visibleCategories: [String] {
        let used = Set(manager.titles.flatMap(\.categories))
        let ordered = manager.categories.map(\.name).filter { used.contains($0) }
        let unlisted = used.subtracting(ordered).sorted()
        return ordered + unlisted
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch manager.loadState {
        case .notConfigured:
            message(Constants.Fleet.notConfigured, detail: manager.configurationProblem, systemImage: "exclamationmark.triangle")
        case .ssoRequired:
            message(Constants.Fleet.signInRequired, systemImage: "person.badge.key") {
                ScButton(Constants.Fleet.signIn) {
                    await openDeviceWebPage()
                }
                .frame(maxWidth: 200)
            }
        case .failed(let error) where manager.titles.isEmpty:
            message("\(Constants.Fleet.couldNotLoad)\n\(error)", systemImage: "exclamationmark.triangle") {
                ScButton(Constants.Fleet.retry) {
                    await manager.refresh()
                }
                .frame(maxWidth: 200)
            }
        case .idle:
            ProgressView(Constants.Fleet.loading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading where manager.titles.isEmpty:
            ProgressView(Constants.Fleet.loading)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            catalog
        }
    }

    @ViewBuilder
    private var catalog: some View {
        let filtered = filteredTitles
        if manager.titles.isEmpty {
            message(Constants.Fleet.noApps, systemImage: "square.grid.2x2")
        } else if filtered.isEmpty {
            message(Constants.Fleet.noMatches, systemImage: "magnifyingglass")
        } else {
            let recommendedApps = FleetRecommendedApps.current
            // Recommended apps stay in their section once installed; updates for them are also listed under
            // Updates Available, so that section matches the update count on Home and in the sidebar
            let recommended = recommendedApps.titles(from: filtered)
            let recommendedIDs = Set(recommended.map(\.id))
            let updates = filtered.filter(manager.hasUpdate)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    section("recommended", recommendedApps.sectionTitle, recommended, highlighted: true)
                    section("updates", Constants.Fleet.updatesAvailable, updates)
                    section("available", Constants.Fleet.available, filtered.filter { !$0.isInstalled && !recommendedIDs.contains($0.id) })
                    section("installed", Constants.Fleet.installed, filtered.filter { $0.isInstalled && !manager.hasUpdate($0) && !recommendedIDs.contains($0.id) })
                }
                .padding(.bottom, 20)
            }
        }
    }

    @ViewBuilder
    private func section(_ id: String, _ name: String, _ titles: [FleetSoftwareTitle], highlighted: Bool = false) -> some View {
        if !titles.isEmpty {
            let isCollapsed = collapsedSectionIDs.contains(id)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { toggleSection(id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .rotationEffect(.degrees(isCollapsed ? 0 : 90))
                        Text("\(name) (\(titles.count))")
                            .font(.headline)
                    }
                    .padding(.leading, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !isCollapsed {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 0) {
                        ForEach(titles) { title in
                            FleetAppCard(title: title, highlighted: highlighted)
                        }
                    }
                }
            }
        }
    }

    private var collapsedSectionIDs: Set<String> {
        Set(collapsedSections.split(separator: ",").map(String.init))
    }

    private func toggleSection(_ id: String) {
        var ids = collapsedSectionIDs
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        collapsedSections = ids.sorted().joined(separator: ",")
    }

    private var filteredTitles: [FleetSoftwareTitle] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return manager.titles.filter { title in
            let matchesCategory = selectedCategory.map { title.categories.contains($0) } ?? true
            let matchesSearch = query.isEmpty
                || title.title.localizedCaseInsensitiveContains(query)
                || title.name.localizedCaseInsensitiveContains(query)
            return matchesCategory && matchesSearch
        }
    }

    private func message(_ text: String, detail: String? = nil, systemImage: String, @ViewBuilder action: () -> some View = { EmptyView() }) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.title3)
                .multilineTextAlignment(.center)
            if let detail {
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
            }
            action()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Opens Fleet's My Device page, which handles sign-in. Replaced by the in-app sign-in sheet.
    private func openDeviceWebPage() async {
        if let url = await FleetClient.shared.deviceWebURL() {
            NSWorkspace.shared.open(url)
        }
    }
}

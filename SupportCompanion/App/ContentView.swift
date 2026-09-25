//
//  ContentView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-11.
//

import Combine
import SwiftUI

struct ContentView: View {
    @State private var selectedItem: SidebarItem?
    @Namespace private var animationNamespace
    @Environment(Preferences.self) var preferences
    @Environment(AppStateManager.self) var appState
    @State private var webViewStateManager = WebViewStateManager()
    @State private var cardGridViewModel = CardGridViewModel(appState: AppStateManager.shared)
    @State private var brandLogo: Image? = nil
    @State private var showLogo: Bool = false
    @State private var isShowingPopup = false
    @State private var modalButtonHovered: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let sidebarItems: [SidebarItem] = generateSidebarItems(
            preferences: appState.preferences, stateManager: webViewStateManager,
            cardGridViewModel: cardGridViewModel, pendingUpdatesCount: appState.pendingUpdatesCount,
            failingChecksCount: appState.fleetFailingChecksCount)
        let accentColor = Color(accentNSColor)

        NavigationSplitView {
            VStack(spacing: 10) {
                Spacer()  // Push content to the center dynamically

                // Logo Section
                if showLogo, let logo = brandLogo {
                    logo
                        .resizable()
                        .interpolation(.high)
                        .antialiased(true)
                        .scaledToFit()
                        .frame(maxWidth: 230)
                        .drawingGroup()
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 20)  // Minimal padding
                        .padding(.horizontal, 20)
                }

                // Title Section
                if !appState.preferences.branding.brandName.isEmpty {
                    Text(appState.preferences.branding.brandName)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20)  // Bring the title closer to the logo
                }

                Spacer()  // Push content to the center dynamically

                // Sidebar List (custom to avoid List clipping)
                SidebarListView(
                    items: sidebarItems,
                    selectedItem: selectedItem,
                    onSelect: { item in
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            selectedItem = item
                        }
                    },
                    accentColor: accentColor,
                    namespace: animationNamespace,
                    onAppear: {
                        loadLogoForCurrentColorScheme()
                        if selectedItem == nil {
                            selectedItem = sidebarItems.first
                        }
                    },
                    onColorSchemeChange: {
                        loadLogoForCurrentColorScheme()
                    },
                    onBrandLogoChange: {
                        loadLogoForCurrentColorScheme()
                    },
                    onBrandLogoLightChange: {
                        loadLogoForCurrentColorScheme()
                    },
                    onIncomingURL: { url in
                        handleIncomingURL(url, items: sidebarItems)
                    }
                )
                .background(Color.clear)
            }
            .navigationSplitViewColumnWidth(
                min: 280, ideal: 280, max: 320
            )
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
        } detail: {
            Group {
                if let selectedItem = selectedItem {
                    selectedItem.destination
                        .id(selectedItem.id)
                } else {
                    Text("Select an option")  // Placeholder if nothing is selected
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.gray.opacity(0.1))
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    ToolbarSupportButton(isShowingPopup: $isShowingPopup)
                }

                if #available(macOS 26.0, *) {
                    ToolbarSpacer(.fixed)
                }

                ToolbarItem(placement: .automatic) {
                    ToolbarDarkModeToggleView()
                }
            }
        }
        .sheet(isPresented: $isShowingPopup) {
            // The popup content
            PopupModal(isShowing: $isShowingPopup)
        }
        // Set the background color based on the color scheme with opacity
        .background(colorScheme == .dark ? Color.black.opacity(0.4) : Color.white.opacity(0.4))
        .background(.ultraThinMaterial)
        // One sign-in sheet for the window: both Fleet pages start the same sign-in, and only one of
        // them is ever in the detail pane. Attached out here rather than to the detail pane, because a
        // sheet centres on the view it is attached to -- on the detail pane it sits off to the right.
        .sheet(isPresented: Bindable(appState.fleetSSOController).isPresented) {
            FleetSSOSignInSheet(controller: appState.fleetSSOController)
        }
    }

    private func handleIncomingURL(_ url: URL, items: [SidebarItem]) {
        guard url.scheme == "supportcompanion" else { return }

        switch url.host?.lowercased() {
        case "home":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.home })
        case "identity":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.identity })
        case "apps":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.apps })
        case "selfservice":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.selfService })
        case "compliance":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.compliance })
        case "companyportal":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.companyPortal })
        case "knowledgebase":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.knowledgeBase })
        case "markdown":
            selectedItem = items.first(where: { $0.id == appState.preferences.markdownMenuLabel })
        case "fleetsignin":
            // Reached from the tray cards and the sign-in notification, where there may be no window
            // yet. Opening the window is the AppDelegate's job; this lands the user somewhere that
            // makes sense once signed in, and puts the sheet up.
            selectedItem = items.first(where: { $0.id == Constants.Navigation.apps })
                ?? items.first(where: { $0.id == Constants.Navigation.compliance })
            appState.fleetSSOController.present()
        default:
            selectedItem = items.first(where: { $0.id == Constants.Navigation.home })
        }
    }

    private func loadLogoForCurrentColorScheme() {
        let preferredLight = appState.preferences.branding.brandLogoLight
        let darkLogo = appState.preferences.branding.brandLogo
        let lightLogo = preferredLight.isEmpty ? darkLogo : preferredLight
        let base64Logo = (colorScheme == .dark) ? darkLogo : lightLogo

        showLogo = loadLogo(base64Logo: base64Logo)
        if showLogo {
            brandLogo = base64ToImage(base64Logo)
        }
    }

    struct ToolbarSupportButton: View {
        @Environment(AppStateManager.self) var appState
        @Binding var isShowingPopup: Bool

        var body: some View {
            if !appState.preferences.supportEmail.isEmpty
                && !appState.preferences.supportPhone.isEmpty
            {
                Button {
                    isShowingPopup = true
                } label: {
                    Label("Support Information", systemImage: "phone")
                }
            }
        }
    }

    struct ToolbarDarkModeToggleView: View {
        var body: some View {
            DarkLightModeToggle()
                .padding(.trailing, 5)
                .padding(.leading, 5)
        }
    }

    struct SidebarRowView: View {
        let item: SidebarItem
        let isSelected: Bool
        let accentColor: Color
        let namespace: Namespace.ID
        let onSelect: () -> Void
        @State private var isHovered: Bool = false

        var body: some View {
            ZStack {
                // Background layers: selected highlight or hover highlight
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(accentColor)
                        .matchedGeometryEffect(id: "sidebar-highlight", in: namespace)
                        .frame(height: 38)
                } else if isHovered {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: 38)
                }

                // Row content
                HStack(spacing: 8) {
                    Image(systemName: item.systemImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)

                    Text(item.label)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.badge > 0 {
                        Text("\(item.badge)")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.white.opacity(0.25) : Color.red)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .foregroundColor(isSelected ? .white : .primary)
            .onTapGesture(perform: onSelect)
            .onHover { hovering in
                isHovered = hovering
            }
        }
    }
}

private struct SidebarListView: View {
    let items: [SidebarItem]
    let selectedItem: SidebarItem?
    let onSelect: (SidebarItem) -> Void
    let accentColor: Color
    let namespace: Namespace.ID

    let onAppear: () -> Void
    let onColorSchemeChange: () -> Void
    let onBrandLogoChange: () -> Void
    let onBrandLogoLightChange: () -> Void
    let onIncomingURL: (URL) -> Void

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(items) { item in
                    ContentView.SidebarRowView(
                        item: item,
                        isSelected: selectedItem == item,
                        accentColor: accentColor,
                        namespace: namespace,
                        onSelect: { onSelect(item) }
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .zIndex(selectedItem == item ? 1 : 0)
                }
            }
            .padding(.vertical, 8)
        }
        .onAppear(perform: onAppear)
        .onChange(of: colorScheme) { _, _ in onColorSchemeChange() }
        .onReceive(NotificationCenter.default.publisher(for: .handleIncomingURL)) { notification in
            if let url = notification.object as? URL {
                onIncomingURL(url)
            }
        }
        .onChange(of: AppStateManager.shared.preferences.branding.brandLogo) { _, _ in
            onBrandLogoChange()
        }
        .onChange(of: AppStateManager.shared.preferences.branding.brandLogoLight) { _, _ in
            onBrandLogoLightChange()
        }
    }

    @Environment(\.colorScheme) private var colorScheme
}

extension ContentView {
    fileprivate var accentNSColor: NSColor {
        NSColor(hex: appState.preferences.branding.accentColor ?? "") ?? NSColor.controlAccentColor
    }
}

struct SidebarItemStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16))
            .bold()
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .toolbar(removing: .sidebarToggle)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(AppStateManager.shared.preferences)
            .environment(DeviceInfoManager.shared)
            .environment(StorageInfoManager.shared)
            .environment(MdmInfoManager.shared)
            .environment(BatteryInfoManager.shared)
            .frame(width: 1500, height: 900)
    }
}

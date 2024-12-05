//
//  ContentView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-11.
//

import SwiftUI
import Combine

struct ContentView: View {
    @State private var selectedItem: SidebarItem?
    @Namespace private var animationNamespace
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var appState: AppStateManager
    @StateObject private var webViewStateManager = WebViewStateManager()
    @State private var brandLogo: Image? = nil
    @State private var showLogo: Bool = false
    @State private var isShowingPopup = false
    @State private var modalButtonHovered: Bool = false
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        let sidebarItems = generateSidebarItems(preferences: appState.preferences, stateManager: webViewStateManager)

        NavigationSplitView {
            VStack(spacing: 10) {
                Spacer() // Push content to the center dynamically

                // Logo Section
                if showLogo, let logo = brandLogo {
                    logo
                        .resizable()
                        .scaledToFit()
                        .padding(.top, 20) // Minimal padding
                        .padding(.horizontal, 20)
                }

                // Title Section
                if !appState.preferences.brandName.isEmpty {
                    Text(appState.preferences.brandName)
                        .font(.title)
                        .multilineTextAlignment(.center)
                        .padding(.top, 20) // Bring the title closer to the logo
                }

                Spacer() // Push content to the center dynamically

                // Sidebar List
                List(sidebarItems, selection: $selectedItem) { item in
                    sidebarItem(for: item)
                }
                .listStyle(SidebarListStyle())
                .onAppear {
                    loadLogoForCurrentColorScheme()
                    if selectedItem == nil {
                        selectedItem = sidebarItems.first
                    }
                }
                .onChange(of: colorScheme) { _, _ in
                    loadLogoForCurrentColorScheme()
                }
                .onChange(of: appState.preferences.brandLogo) { _, _ in
                    loadLogoForCurrentColorScheme()
                }
                .onChange(of: appState.preferences.brandLogoLight) { _, _ in
                    loadLogoForCurrentColorScheme()
                }
                .onReceive(NotificationCenter.default.publisher(for: .handleIncomingURL)) { notification in
                    if let url = notification.object as? URL {
                        handleIncomingURL(url, items: sidebarItems)
                    }
                }
                .background(Color.clear)
                
                if !appState.preferences.supportEmail.isEmpty && !appState.preferences.supportPhone.isEmpty {
                    HStack {
                        Spacer()
                        Button(action: {
                            isShowingPopup = true // Show popup
                        }) {
                            Text("Support Information")
                                .padding()
                                .foregroundColor(
                                    modalButtonHovered
                                    ? Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor)
                                    : .primary
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovering in
                            modalButtonHovered = hovering
                        }
                        Spacer()
                    }
                }

                HStack {
                    Spacer()
                    DarkLightModeToggle()
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .navigationSplitViewColumnWidth(
                min: 280, ideal: 280, max: 320)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color.clear)
        } detail: {
            if let selectedItem = selectedItem {
                selectedItem.destination
                    .id(selectedItem.id)
                    .ignoresSafeArea(edges: .all)
            } else {
                Text("Select an option") // Placeholder if nothing is selected
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.gray.opacity(0.2))
            }
        }
        .sheet(isPresented: $isShowingPopup) {
            // The popup content
            PopupModal(isShowing: $isShowingPopup)
        }
        .background(.clear)
        .background(.ultraThinMaterial)
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
        case "companyportal":
            selectedItem = items.first(where: { $0.id == "Company Portal" })
        case "knowledgebase":
            selectedItem = items.first(where: { $0.id == Constants.Navigation.knowledgeBase })
        default:
            Logger.shared.logDebug("Unhandled URL: \(url)")
        }
    }
    
    private func loadLogoForCurrentColorScheme() {
        let base64Logo = colorScheme == .dark ? appState.preferences.brandLogo : appState.preferences.brandLogoLight.isEmpty ? appState.preferences.brandLogo : appState.preferences.brandLogoLight
        loadLogo(base64Logo: base64Logo)
    }
    
    private func loadLogo(base64Logo: String) {
        if base64Logo.isEmpty {
            showLogo = false
        } else if let decodedImage = base64ToImage(base64Logo) {
            brandLogo = decodedImage
            showLogo = true
        } else {
            Logger.shared.logDebug("Invalid Base64 string for brand logo.")
            showLogo = false
        }
    }


    @ViewBuilder
    private func sidebarItem(for item: SidebarItem) -> some View {
        HStack {
            Image(systemName: item.systemImage)
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
            Text(item.label)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            Group {
                if selectedItem == item {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                        .matchedGeometryEffect(id: "sidebar-highlight", in: animationNamespace)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.clear)
                }
            }
        )
        .contentShape(Rectangle()) // Makes the entire area tappable
        .foregroundColor(selectedItem == item ? .white : .primary)
        .onTapGesture {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                selectedItem = item
            }
        }
        .onHoverEffect(item)
    }
}

struct SidebarItemStyle: ViewModifier {
    //@State private var isHovered = false
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
            .environmentObject(Preferences())
            .environmentObject(DeviceInfoManager.shared)
            .environmentObject(StorageInfoManager.shared)
            .environmentObject(MdmInfoManager.shared)
            .environmentObject(BatteryInfoManager.shared)
            .frame(width: 1400, height: 800)
    }
}

private extension View {
    func onHoverEffect(_ item: SidebarItem) -> some View {
        modifier(HoverEffectModifier(item: item))
    }
}

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    let item: SidebarItem

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color.black.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

func base64ToImage(_ base64String: String) -> Image? {
    // Decode Base64 string to Data
    guard let imageData = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters),
          let cgImageSource = CGImageSourceCreateWithData(imageData as CFData, nil),
          let cgImage = CGImageSourceCreateImageAtIndex(cgImageSource, 0, nil) else {
        Logger.shared.logDebug("Failed to decode Base64 string to Image")
        return nil
    }

    // Return a SwiftUI Image
    return Image(decorative: cgImage, scale: 1.0, orientation: .up)
}


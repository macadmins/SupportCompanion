//
//  TransparentView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-11.
//

import Foundation
import SwiftUI


struct TransparentView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var contentHeight: CGFloat = 0
    var combinedPreferences: String {
        "\(appState.preferences.desktopInfoLevel)-\(appState.preferences.desktopInfoHideItems.joined(separator: ","))"
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.black.opacity(appState.preferences.desktopInfoBackgroundOpacity))
                .shadow(radius: 10) // Shadow for depth
                .clipShape(RoundedRectangle(cornerRadius: 15)) // Ensure clipping

            VStack(alignment: .leading) {
                // Title for the Info View
                if !appState.preferences.desktopInfoHideItems.contains("Category") {
                    Text(Constants.CardTitle.deviceInfo)
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                        .shadow(radius: 2)
                }

                // Grouped Device Information
                ForEach(Array(groupedDeviceInfoArray().enumerated()), id: \.1.0) { index, group in
                    SectionHeaderTransparent(
                        title: group.0, 
                        addHeader: shouldShowGategory(), 
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    ) // Section title (e.g., "Hardware Specifications")
                    VStack(alignment: .leading) {
                        ForEach(group.1.filter { !appState.preferences.desktopInfoHideItems.contains($0.key) }, id: \.key) { item in
                            deviceInfoRow(for: item)
                        }
                        .id(appState.preferences.desktopInfoHideItems)
                    }

                    // Add a divider only if it's not the last group
                    if index < groupedDeviceInfoArray().count - 1 {
                        shouldShowDivider()
                            .background(Color.white.opacity(0.2))
                            .shadow(radius: 2)
                            .padding(.vertical, 5)
                    }
                }

                if appState.preferences.desktopInfoLevel > 3 && !appState.preferences.desktopInfoHideItems.contains("Storage"){
                    // Storage Section
                    shouldShowDivider()
                        .background(Color.white.opacity(0.2))
                        .shadow(radius: 2)
                        .padding(.vertical, 5)
                    
                    SectionHeaderTransparent(
                        title: Constants.CardTitle.storage, 
                        addHeader: shouldShowGategory(), 
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    )
                    storageInfoSection()
                }
                
                if appState.preferences.desktopInfoLevel > 4 && !appState.preferences.desktopInfoHideItems.contains("Support"){
                    shouldShowDivider()
                        .background(Color.white.opacity(0.2))
                        .shadow(radius: 2)
                        .padding(.vertical, 5)
                    
                    SectionHeaderTransparent(
                        title: Constants.Support.Titles.support, 
                        addHeader: shouldShowGategory(), 
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    )
                    supportInfoSection()
                }
            }
            .id(combinedPreferences)
            .padding()
            .background(GeometryReader { geometry in
                Color.clear
                    .onChange(of: combinedPreferences) { _ in
                        contentHeight = geometry.size.height // Recalculate height
                    }
                    .onAppear {
                        contentHeight = geometry.size.height // Initial calculation
                    }
            })
        }
        .frame(height: contentHeight)
    }

    private func shouldShowDivider() -> some View {
        !appState.preferences.desktopInfoHideItems.contains("Divider")
            ? AnyView(Divider())
            : AnyView(EmptyView())
    }
    
    private func shouldShowGategory() -> Bool {
        !appState.preferences.desktopInfoHideItems.contains("Category")
    }
    
    private func localizedHideCheck(_ standardKey: String) -> Bool {
        let hideItems = appState.preferences.desktopInfoHideItems

        // Map the user-provided keys to localized values
        let localizedKeys = hideItems.compactMap { key in
            switch key {
            case "Network Information":
                return Constants.DeviceInfo.Categories.networkInfo
            case "Hardware Specifications":
                return Constants.DeviceInfo.Categories.hardwareSpecs
            case "System Information":
                return Constants.DeviceInfo.Categories.systemInfo
            default:
                return key // Fallback for unknown keys
            }
        }

        // Check if the localized key matches the standard key
        return localizedKeys.contains(standardKey)
    }
    
    private func groupedDeviceInfoArray() -> [(String, [(key: String, display: String, value: InfoValue)])] {
        groupedDeviceInfo()
            .compactMap { section in
                let isIncludedByLevel: Bool
                switch appState.preferences.desktopInfoLevel {
                case 1:
                    isIncludedByLevel = section.key == Constants.DeviceInfo.Categories.hardwareSpecs
                case 2:
                    isIncludedByLevel = section.key == Constants.DeviceInfo.Categories.hardwareSpecs ||
                                        section.key == Constants.DeviceInfo.Categories.systemInfo
                case 3:
                    isIncludedByLevel = section.key == Constants.DeviceInfo.Categories.hardwareSpecs ||
                                        section.key == Constants.DeviceInfo.Categories.systemInfo ||
                                        section.key == Constants.DeviceInfo.Categories.networkInfo
                default:
                    isIncludedByLevel = true
                }

                // Always allow hiding based on desktopInfoHideItems
                if isIncludedByLevel && !localizedHideCheck(section.key) {
                    return (section.key, section.value)
                }
                return nil
            }
            .sorted(by: { $0.0 < $1.0 })
    }

    private func groupedDeviceInfo() -> [String: [(key: String, display: String, value: InfoValue)]] {
        guard let deviceInfo = appState.deviceInfoManager.deviceInfo else {
            return [:]
        }

        return Dictionary(
            grouping: deviceInfo.toKeyValuePairs().sorted(by: { $0.key < $1.key }),
            by: { $0.category }
        )
        .mapValues { tuples in
            tuples.map { (key: $0.key, display: $0.display, value: $0.value) }
        }
    }
    
    private func deviceInfoRow(for item: (key: String, display: String, value: InfoValue)) -> some View {
        if item.key == Constants.DeviceInfo.Keys.lastRestart {
            return AnyView(
                LastRestartRowTransparent(
                    label: item.display,
                    value: item.value.rawValue as? Int ?? 0,
                    fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                )
            )
        } else {
            return AnyView(
                DeviceInfoRowTransparent(
                    label: item.display,
                    value: item.value.displayValue,
                    fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                )
                .id(item.value.displayValue)
            )
        }
    }
    
    private func storageInfoSection() -> some View {
        VStack(alignment: .leading) {
            ForEach(appState.storageInfoManager.storageInfo.toKeyValuePairs(), id: \.key) { item in
                if appState.preferences.desktopInfoHideItems.count > 0 {
                    if appState.preferences.desktopInfoHideItems.contains(item.key) {
                        EmptyView()
                    }
                }
                if item.key == "FileVault" {
                    StorageInfoRowTransparent(
                        label: item.display,
                        value: item.value.displayValue,
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    )
                    usageInfoRowTransparent(
                        value: appState.storageInfoManager.storageInfo.usage,
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    )
                } else {
                    StorageInfoRowTransparent(
                        label: item.display,
                        value: item.value.displayValue,
                        fontSize: CGFloat(appState.preferences.desktopInfoFontSize)
                    )
                }
            }
            .id(appState.preferences.desktopInfoHideItems)
        }
    }
    
    private func supportInfoSection() -> some View {
        VStack(alignment: .leading) {
            if !appState.preferences.desktopInfoHideItems.contains(Constants.Support.Keys.phone) {
                HStack {
                    Text(Constants.Support.Labels.phone)
                        .font(.system(size: CGFloat(appState.preferences.desktopInfoFontSize)))
                        .bold()
                    Spacer()
                    Text(appState.preferences.supportPhone)
                        .font(.system(size: CGFloat(appState.preferences.desktopInfoFontSize)))
                        .shadow(radius: 2)
                }
            }
            if !appState.preferences.desktopInfoHideItems.contains(Constants.Support.Keys.email) {
                HStack {
                    Text(Constants.Support.Labels.email)
                        .font(.system(size: CGFloat(appState.preferences.desktopInfoFontSize)))
                        .bold()
                    Spacer()
                    Text(appState.preferences.supportEmail)
                        .font(.system(size: CGFloat(appState.preferences.desktopInfoFontSize)))
                        .shadow(radius: 2)
                }
            }
        }
        .id(appState.preferences.desktopInfoHideItems)
    }
}

struct SectionHeaderTransparent: View {
    let title: String
    let addHeader: Bool
    let fontSize: CGFloat

    // Computed property for the image name
    private var image: String {
        switch title {
        case Constants.DeviceInfo.Categories.hardwareSpecs:
            return "cpu.fill"
        case Constants.DeviceInfo.Categories.systemInfo:
            return "info.circle.fill"
        case Constants.DeviceInfo.Categories.networkInfo:
            return "wifi"
        case Constants.CardTitle.storage:
            return "internaldrive.fill"
        case Constants.Support.Titles.support:
            return "phone.badge.waveform.fill"
        default:
            return "questionmark.circle.fill" // Fallback icon
        }
    }

    var body: some View {
        if addHeader {
            HStack(spacing: 8) {
                Image(systemName: image)
                Text(title)
                    .font(.system(size: fontSize))
            }
            .shadow(radius: 2)
            .padding(.vertical, 5)
        } else {
            EmptyView()
        }
    }
}

struct DeviceInfoRowTransparent: View {
    let label: String
    let value: String?
    let fontSize: CGFloat
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fontSize))
                .bold()
            Spacer()
            Text(value ?? "N/A")
                .font(.system(size: fontSize))
                .shadow(radius: 2)
        }
        .shadow(radius: 2)
        .background(Color.clear)
    }
}

struct StorageInfoRowTransparent: View {
    let label: String
    let value: String?
    let fontSize: CGFloat
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fontSize))
                .bold()
            Spacer()
            Text(value ?? "N/A")
                .font(.system(size: fontSize))
                .shadow(radius: 2)
        }
    }
}

struct usageInfoRowTransparent: View {
    let value: Double
    let fontSize: CGFloat
    
    var body: some View {
        HStack {
            Text(Constants.Battery.Labels.usage)
                .font(.system(size: fontSize))
                .bold()
            Spacer()
            Text("\(String(format: "%.1f", value))%")
                .font(.system(size: fontSize))
                .shadow(radius: 2)
        }
    }
}

struct LastRestartRowTransparent: View {
    let label: String
    let value: Int // Days since last restart
    let fontSize: CGFloat
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: fontSize))
                .bold()
            Spacer()
            HStack(spacing: 5) {
                Text("\(value) \(Constants.General.days)")
                .shadow(radius: 2)
                Image(systemName: "clock.fill")
            }
            .font(.system(size: fontSize))
            .shadow(radius: 2)
        }
    }
}

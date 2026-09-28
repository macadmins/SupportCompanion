//
//  AppCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-24.
//

import Foundation
import SwiftUI

// Mode-specific details (version, icon, button label) are resolved by ApplicationsInfoManager when the
// list is built, so this view only displays them.
struct AppCard: View {
    let card: InstalledApp
    
    @State private var resolvedTitleImage: String = "app.gift.fill"

    private var version: String { card.version }

    var titleImage: String {
        card.iconPath ?? resolvedTitleImage
    }
    
    private var buttonText: String {
        card.actionText ?? ""
    }

    var body: some View {
        ScCard(
            title: card.name,
            titleImageName: titleImage,
            imageSize: (40, 40),
            content: {
                VStack(alignment: .leading, spacing: 5) {
                    if !version.isEmpty {
                        HStack(alignment: .top) {
                            Text("\(Constants.TableHeaders.version):")
                                .bold()
                            Text(version)
                        }
                        .font(.system(size: 14))
                    }
                    
                    if !card.arch.isEmpty {
                        HStack {
                            Text("Arch:")
                                .bold()
                            Text(card.arch)
                        }
                        .font(.system(size: 14))
                    }
                    
                    if !card.type.isEmpty {
                        HStack {
                            Text("Type:")
                                .bold()
                            Text(card.type)
                        }
                        .font(.system(size: 14))
                    }
                    
                    HStack {
                        if card.isSelfServe {
                            ScButton(buttonText, action: {
                                if !card.action.isEmpty {
                                    do {
                                        _ = try await ExecutionService.executeShellCommand(card.action)
                                    } catch {
                                        Logger.shared.logError("App card action '\(card.action)' failed: \(error)")
                                    }
                                }
                            })
                            .padding(.top, 40)
                        }
                        if AppStateManager.shared.preferences.mode == Constants.Modes.jamf {
                            if let pending = AppStateManager.shared.pendingJamfUpdates.first(where: { $0.policyName == card.name }),
                               let patchID = pending.patchId {
                                let isRunning = AppStateManager.shared.pendingJamfUpdatesManager.isRunning(patchId: patchID)
                                ScButton(isRunning ? "Updating…" : "Update", action: {
                                    await AppStateManager.shared.pendingJamfUpdatesManager.runPatch(patchId: patchID)
                                })
                                .disabled(isRunning)
                                .padding(.top, 40)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        )
        .task {
            await loadRemoteIconIfNeeded()
        }
    }
    
    @MainActor
    private func loadRemoteIconIfNeeded() async {
        guard card.iconPath == nil, let iconUrl = card.iconUrl, !iconUrl.isEmpty else { return }
        // Attempt to download icon asynchronously
        if let iconPath = try? await downloadAppIcon(forApp: card) {
            resolvedTitleImage = iconPath
        } else {
            // Keep fallback if download fails
            resolvedTitleImage = "app.gift.fill"
        }
    }
}

// Utility Functions
func getIconPath(plistPath: String, appPath: String) -> String? {
    if FileManager.default.fileExists(atPath: plistPath) {
        if let iconName = PlistService.getPlistValue(forKey: "CFBundleIconFile", fromPlistAtPath: plistPath) as? String {
            let resolvedIconName = iconName.hasSuffix(".icns") ? iconName : "\(iconName).icns"
            let appIconPath = "\(appPath)/Contents/Resources/\(resolvedIconName)"
            if FileManager.default.fileExists(atPath: appIconPath) {
                return appIconPath
            }
        }
    }
    return nil
}

func getAppVersion(plistPath: String) -> String? {
    if FileManager.default.fileExists(atPath: plistPath) {
        if let appVersion = PlistService.getPlistValue(forKey: "CFBundleShortVersionString", fromPlistAtPath: plistPath) as? String {
            return appVersion
        }
    }
    return nil
}
    
struct PlistService {
    /// Reads a value from a plist file at the given path for the specified key
    static func getPlistValue(forKey key: String, fromPlistAtPath path: String) -> Any? {
        // Ensure the file exists at the given path
        guard FileManager.default.fileExists(atPath: path),
              let plistData = FileManager.default.contents(atPath: path) else {
            Logger.shared.logError("Could not read plist at path: \(path)")
            return nil
        }
        
        do {
            // Deserialize the plist into a dictionary
            if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                return plist[key]
            }
        } catch {
            Logger.shared.logError("Error: Failed to parse plist. \(error.localizedDescription)")
        }
        
        return nil
    }
}


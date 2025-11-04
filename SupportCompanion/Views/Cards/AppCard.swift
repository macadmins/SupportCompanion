//
//  AppCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-24.
//

import Foundation
import SwiftUI

struct AppCard: View {
    let card: InstalledApp
    let version: String
    
    @State private var resolvedTitleImage: String = "app.gift.fill"

    init(card: InstalledApp) {
        self.card = card

        // Determine version
        if AppStateManager.shared.preferences.mode == Constants.modes.intune,
           let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: card.bundleId) {
            let appInfoPlistPath = "\(appURL.path)/Contents/Info.plist"
            self.version = getAppVersion(plistPath: appInfoPlistPath) ?? "Unknown"
        } else {
            self.version = card.version
        }
    }

    var titleImage: String {
        if AppStateManager.shared.preferences.mode == Constants.modes.munki {
            let iconPath = "/Library/Managed Installs/icons/\(card.name).png"
            if FileManager.default.fileExists(atPath: iconPath) {
                return iconPath
            } else {
                return resolvedTitleImage
            }
        } else if AppStateManager.shared.preferences.mode == Constants.modes.systemProfiler {
            let appInfoPlistPath = "\(card.path)/Contents/Info.plist"
            return getIconPath(plistPath: appInfoPlistPath, appPath: card.path) ?? resolvedTitleImage
        } else if AppStateManager.shared.preferences.mode == Constants.modes.intune {
            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: card.bundleId) {
                let appInfoPlistPath = "\(appURL.path)/Contents/Info.plist"
                return getIconPath(plistPath: appInfoPlistPath, appPath: appURL.path) ?? resolvedTitleImage
            } else {
                return resolvedTitleImage
            }
        } else if AppStateManager.shared.preferences.mode == Constants.modes.jamf {
            // For JAMF, the actual download is handled asynchronously; fall back to current state value
            return resolvedTitleImage
        }
        return resolvedTitleImage
    }
    
    private var buttonText: String {
        if AppStateManager.shared.preferences.mode == Constants.modes.jamf {
            return card.actionText ?? ""
        } else {
            return Constants.General.manage
        }
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
                            Text("\(Constants.TabelHeaders.version):")
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
									_ = try? await ExecutionService.executeShellCommand(card.action)
								}
							})
							.padding(.top, 40)
						}
						if AppStateManager.shared.preferences.mode == Constants.modes.jamf {
							if AppStateManager.shared.pendingJamfUpdates.contains(where: { $0.policyName == card.name }) {
								let patchID = AppStateManager.shared.pendingJamfUpdates.first(where: { $0.policyName == card.name })!.patchId
								ScButton("Update", action: {
									_ = try? await ExecutionService.executeCommandPrivileged("/bin/launchctl", arguments: ["asuser", "504", "/usr/local/bin/jamf", "patch", "-id", String(patchID!), "-showSteps", "-selfServiceOnly", "-user", "tobal86"])
									await AppStateManager.shared.pendingJamfUpdatesManager.getPendingJamfUpdates()
								})
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
            await loadJamfIconIfNeeded()
        }
    }
    
    @MainActor
    private func loadJamfIconIfNeeded() async {
        guard AppStateManager.shared.preferences.mode == Constants.modes.jamf else { return }
        guard let iconUrl = card.iconUrl, !iconUrl.isEmpty else { return }
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


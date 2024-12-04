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

    var titleImage: String {
        if AppStateManager.shared.preferences.mode == Constants.modes.munki {
            let iconPath = "/Library/Managed Installs/icons/\(card.name).png"
            if FileManager.default.fileExists(atPath: iconPath) {
                return iconPath
            } else {
                return "app.gift.fill" // Fallback to SF Symbol
            }
        } else if AppStateManager.shared.preferences.mode == Constants.modes.systemProfiler {
            let appInfoPlistPath = "\(card.path)/Contents/Info.plist"
            if FileManager.default.fileExists(atPath: appInfoPlistPath) {
                // Get icon name from Info.plist
                if let iconName = PlistService.getPlistValue(forKey: "CFBundleIconFile", fromPlistAtPath: appInfoPlistPath) as? String {
                    let resolvedIconName = iconName.hasSuffix(".icns") ? iconName : "\(iconName).icns"
                    let appIconPath = "\(card.path)/Contents/Resources/\(resolvedIconName)"
                    if FileManager.default.fileExists(atPath: appIconPath) {
                        return appIconPath
                    }
                }
            }
        }
        return "app.gift.fill" // Default
    }

    var body: some View {
        CustomCard(
            title: card.name,
            titleImageName: titleImage,
            imageSize: (40, 40),
            content: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        Text("\(Constants.TabelHeaders.version):")
                            .bold()
                        Text(card.version)
                    }
                    .font(.system(size: 14))
                    
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

                    if card.isSelfServe {
                        CustomButton(Constants.General.manage, action: {
                            Task {
                                if !card.action.isEmpty {
                                    _ = try await ExecutionService.executeShellCommand(card.action)
                                }
                            }
                        })
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        )
    }
}
    
struct PlistService {
    /// Reads a value from a plist file at the given path for the specified key
    static func getPlistValue(forKey key: String, fromPlistAtPath path: String) -> Any? {
        // Ensure the file exists at the given path
        guard FileManager.default.fileExists(atPath: path),
              let plistData = FileManager.default.contents(atPath: path) else {
            print("Error: Could not read plist at path: \(path)")
            return nil
        }
        
        do {
            // Deserialize the plist into a dictionary
            if let plist = try PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] {
                return plist[key]
            }
        } catch {
            print("Error: Failed to parse plist. \(error.localizedDescription)")
        }
        
        return nil
    }
}

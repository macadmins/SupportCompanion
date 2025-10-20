//
//  CardView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation
import SwiftUI

struct ScCard<Content: View>: View {
    let title: String
    let titleImageName: String?
    let subtitle: String?
    let description: String?
    let content: Content
    let buttonImageName: String?
    let buttonAction: (() async -> Void)?
    let buttonHelpText: String?
    let imageSize: (CGFloat, CGFloat)?
    let useMultiColor: Bool?
    @EnvironmentObject var preferences: Preferences
    @EnvironmentObject var appState: AppStateManager

    init(
        title: String,
        titleImageName: String? = nil,
        subtitle: String? = nil,
        description: String? = nil,
        buttonImageName: String? = nil,
        buttonAction: (() async -> Void)? = nil,
        buttonHelpText: String? = nil,
        imageSize: (CGFloat, CGFloat) = (18, 18),
        useMultiColor: Bool = true,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.titleImageName = titleImageName
        self.subtitle = subtitle
        self.description = description
        self.buttonImageName = buttonImageName
        self.buttonAction = buttonAction
        self.buttonHelpText = buttonHelpText
        self.content = content()
        self.imageSize = imageSize
        self.useMultiColor = useMultiColor
    }
    
    private func loadImage(from path: String) -> NSImage? {
        let url = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: url.path) {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with optional button aligned to the right
            HStack {
                if let titleImageName = titleImageName {
                    if let image = loadImage(from: titleImageName) {
                        Image(nsImage: image) // Use `nsImage` for macOS
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize?.0, height: imageSize?.1)
                    } else {
                        Image(systemName: titleImageName)
                            .resizable()
                            .imageScale(.large)
                            .symbolRenderingMode((useMultiColor ?? true) ? .multicolor : .monochrome)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize?.0, height: imageSize?.1)
                    }
                }
                
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                    .lineLimit(nil) // Allow unlimited lines
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Optional button
                if let buttonImageName = buttonImageName, let buttonAction = buttonAction {
                    Button(action: {
                        Task {
                            await buttonAction()
                        }
                    }) {
                        //Image(systemName: buttonImageName)
                        //    .font(.system(size: 16))
                        //    .foregroundColor(Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
						InfoHelp(text: buttonHelpText ?? "", icon: buttonImageName, color: Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                    }
                    .buttonStyle(PlainButtonStyle())
                    //.help(buttonHelpText ?? "")
                }
            }
            .padding()
            
            // Subtitle (optional)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil) // Allow unlimited lines
                    .multilineTextAlignment(.leading)
                    .padding([.leading, .trailing])
            }

            // Custom content view (optional)
            content

            // Description (optional)
            if let description = description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil) // Allow unlimited lines
                    .multilineTextAlignment(.leading)
                    .padding([.leading, .trailing])
            }

            Spacer()
        }
        .padding()
        /*.background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )*/
        .isGlass()
        .cornerRadius(10)
        .shadow(radius: 4)
        .padding(5)
    }
}

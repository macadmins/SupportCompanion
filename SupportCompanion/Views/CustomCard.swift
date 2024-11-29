//
//  CardView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation
import SwiftUI

struct CustomCard<Content: View>: View {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Title with optional button aligned to the right
            HStack {
                if titleImageName != nil {
                    Image(systemName: titleImageName!)
                        .resizable()
                        .imageScale(.large)
                        .symbolRenderingMode((useMultiColor ?? true) ? .multicolor : .monochrome)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize?.0, height: imageSize?.1)
                }
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Optional button
                if let buttonImageName = buttonImageName, let buttonAction = buttonAction {
                    Button(action: {
                        Task {
                            await buttonAction()
                        }
                    }) {
                        Image(systemName: buttonImageName)
                            .font(.system(size: 16))
                            .foregroundColor(Color(NSColor(hex: appState.preferences.accentColor ?? "") ?? NSColor.controlAccentColor))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(buttonHelpText ?? "")
                }
            }
            .padding()
            
            // Subtitle (optional)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding([.leading, .trailing])
            }

            // Custom content view (optional)
            content

            // Description (optional)
            if let description = description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .padding([.leading, .trailing])
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .cornerRadius(10)
        .shadow(radius: 4)
        .padding(5)
    }
}

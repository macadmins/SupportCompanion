//
//  ScCardCompact.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-07.
//

import SwiftUI

struct ScCardCompact<Content: View>: View {
    let title: String
    let titleImageName: String?
    let subtitle: String?
    let description: String?
    let content: Content
    let buttonImageName: String?
    let buttonAction: (() async -> Void)?
    let imageSize: (CGFloat, CGFloat)?
    let useMultiColor: Bool?

    init(
        title: String,
        titleImageName: String? = nil,
        subtitle: String? = nil,
        description: String? = nil,
        buttonImageName: String? = nil,
        buttonAction: (() async -> Void)? = nil,
        imageSize: (CGFloat, CGFloat) = (16, 16),
        useMultiColor: Bool = true,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.titleImageName = titleImageName
        self.subtitle = subtitle
        self.description = description
        self.buttonImageName = buttonImageName
        self.buttonAction = buttonAction
        self.content = content()
        self.imageSize = imageSize
        self.useMultiColor = useMultiColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Increased spacing for breathing room
            // Header Section
            HStack {
                if let titleImageName = titleImageName {
                    Image(systemName: titleImageName)
                        .resizable()
                        .symbolRenderingMode((useMultiColor ?? true) ? .multicolor : .monochrome)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageSize?.0, height: imageSize?.1)
                }

                Text(title)
                    .font(.system(size: 13))
                    .lineLimit(nil) // Allow text to expand vertically
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let buttonImageName = buttonImageName, let buttonAction = buttonAction {
                    Button(action: {
                        Task {
                            await buttonAction()
                        }
                    }) {
                        Image(systemName: buttonImageName)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)

            // Subtitle (if provided)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(nil) // Allow text to expand vertically
                    .multilineTextAlignment(.leading)
                    .padding([.leading, .trailing])
            }

            // Custom Content (Optional)
            content
                .padding([.leading, .trailing])

            // Description (if provided)
            if let description = description {
                Text(description)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(nil) // Allow text to expand vertically
                    .multilineTextAlignment(.leading)
                    .padding([.leading, .trailing])
            }

            Spacer() // Allow the card to expand vertically
        }
        .padding(.top) // Padding around the entire card
        /*.background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )*/
        .isGlass()
        .shadow(radius: 4) // Adjust shadow for better appearance
        .padding(5)
    }
}

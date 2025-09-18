//
//  ScCardCompactButton.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-07.
//


import SwiftUI

struct ScCardCompactButton<Content: View>: View {
    let title: String
    let titleImageName: String?
    let content: Content
    let buttonImageName: String?
    let buttonAction: Action?
    let customAction: (() async -> Void)?
    let imageSize: (CGFloat, CGFloat)?
    let useMultiColor: Bool?

    @State private var isHovered: Bool = false
    @State private var actionStatus: String? = nil
    @State private var isRunning: Bool = false // Track if the action is running

    init(
        title: String,
        titleImageName: String? = nil,
        buttonImageName: String? = nil,
        buttonAction: Action? = nil,
        customAction: (() async -> Void)? = nil,
        imageSize: (CGFloat, CGFloat) = (16, 16),
        useMultiColor: Bool = true,
        @ViewBuilder content: () -> Content = { EmptyView() }
    ) {
        self.title = title
        self.titleImageName = titleImageName
        self.buttonImageName = buttonImageName
        self.buttonAction = buttonAction
        self.customAction = customAction
        self.content = content()
        self.imageSize = imageSize
        self.useMultiColor = useMultiColor
    }

    var body: some View {
        Button(action: {
            if customAction != nil {
                Task {
                    isRunning = true // Set running state to true
                    await customAction!()
                    isRunning = false // Reset running state
                }
            }

            if let buttonAction = buttonAction {
                Task {
                    isRunning = true // Set running state to true
                    _ = try await ExecutionService.executeShellCommand(buttonAction.command, isPrivileged: buttonAction.isPrivileged)
                    isRunning = false // Reset running state
                }
            }
        }) {
            VStack(alignment: .center, spacing: 10) {
                // Header Section
                VStack(alignment: .center) {
                    if let titleImageName = titleImageName {
                        Image(systemName: titleImageName)
                            .resizable()
                            .symbolRenderingMode((useMultiColor ?? true) ? .multicolor : .monochrome)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: imageSize?.0, height: imageSize?.1)
                            .padding(.bottom)
                    }

                    Text(title)
                        .font(.system(size: 12))
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .center)

                    if let buttonImageName = buttonImageName {
                        Image(systemName: buttonImageName)
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal)

                // Custom Content (Optional)
                content
                    .padding([.leading, .trailing])

                Spacer()
            }
            .overlay {
                if isRunning {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1)
                }
            }
            .padding(.top)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
            //.shadow(radius: isHovered ? 8 : 4)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .isGlass()
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isRunning) // Disable button while the action is running
    }
}

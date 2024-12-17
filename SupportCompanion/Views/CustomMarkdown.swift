//
//  CustomMarkdown.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-17.
//

import Foundation
import SwiftUI
import MarkdownUI

struct CustomMarkdown: View {
    var markdown: String

    var body: some View {
        ZStack {
            ScrollView {
                Markdown(markdown)
                    .lineSpacing(2)
                    .markdownTheme(.sc)
                    .markdownTextStyle {
                        FontSize(14)
                    }
                    .focusable(false)
                    .padding(20)
            }
        }
        .background(Color.clear)
    }
}

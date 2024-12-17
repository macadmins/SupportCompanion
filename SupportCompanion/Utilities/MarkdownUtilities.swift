//
//  MarkdownUtilities.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-17.
//

import Foundation

func loadMarkdown(mdPath: String) -> String {
    if FileManager.default.fileExists(atPath: mdPath),
        let data = FileManager.default.contents(atPath: mdPath),
        let markdownString = String(data: data, encoding: .utf8) {
        return markdownString
    } else {
        Logger.shared.logDebug("Failed to load markdown file.")
    }
    return ""
}
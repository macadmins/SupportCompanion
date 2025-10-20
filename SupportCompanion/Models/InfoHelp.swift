//
//  InfoHelp.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-10-14.
//

import Foundation
import SwiftUI

struct InfoHelp: View {
	let text: String
	let icon: String?
	let color: Color?
	@State private var hovering = false

	var body: some View {
		Image(systemName: "\(icon ?? "info.circle")")
			.frame(width: 24, height: 24)
			.contentShape(Rectangle())
			.onHover { hovering = $0 }
			.foregroundColor(color ?? nil)
			.popover(isPresented: $hovering, arrowEdge: .top) {
				Text(text.isEmpty ? "Details missing" : text).padding()
		}
	}
}

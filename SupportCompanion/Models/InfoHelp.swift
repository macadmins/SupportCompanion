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

	@State private var hoveringRaw = false       // raw hover state
	@State private var hoveringPopover = false   // delayed popover state

	var body: some View {
		Image(systemName: icon ?? "info.circle")
			.frame(width: 24, height: 24)
			.contentShape(Rectangle())
			.foregroundColor(color)
			.onHover { inside in
				hoveringRaw = inside

				if inside {
					// Delay before opening popover
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
						if hoveringRaw {        // still hovering
							hoveringPopover = true
						}
					}
				} else {
					hoveringPopover = false     // close immediately
				}
			}
			.popover(isPresented: $hoveringPopover, arrowEdge: .top) {
				Text(text.isEmpty ? "Details missing" : text)
					.padding()
			}
	}
}

//
//  CompactJamfInfoCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-11-12.
//

import Foundation
import SwiftUI

struct CompactJamfInfoCard: View {
	@EnvironmentObject var appState: AppStateManager

	var body: some View {
		ScCardCompact(
			title: "Jamf",
			titleImageName: "server.rack",
			imageSize: (13, 13),
			content: {
				CardData(info: appState.jamfInfoManager.jamfInfo.toKeyValuePairs(), fontSize: 12)
			}
		)
	}
}

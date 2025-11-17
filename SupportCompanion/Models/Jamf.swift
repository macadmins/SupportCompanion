//
//  Jamf.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2025-11-12.
//

import Foundation

struct JamfInfo: Codable {
	let lastCheckIn: String
	let lastInventory: String
	let url: String
	let jamfID: String
	
	func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
			(
				key: Constants.JamfInfo.Keys.id,
				display: Constants.JamfInfo.Labels.id,
				value: .string(jamfID)
			),
            (
				key: Constants.JamfInfo.Keys.lastCheckin,
				display: Constants.JamfInfo.Labels.lastCheckin,
                value: .string(lastCheckIn)
            ),
			(
				key: Constants.JamfInfo.Keys.lastInventory,
				display: Constants.JamfInfo.Labels.lastInventory,
				value: .string(lastInventory)
			),
			(
				key: Constants.JamfInfo.Keys.url,
				display: Constants.JamfInfo.Labels.url,
				value: .string(url)
			)
        ]
    }
}

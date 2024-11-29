//
//  MDM.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import SwiftUI

struct MdmInfo: Identifiable {
    let id: UUID
    let abm: String
    let enrolled: String
    let enrolledDate: String
    
    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: "AppleBusinessManager",
                display: "Apple Business Manager:",
                value: .string(abm)
            ),
            (
                key: Constants.MDM.Keys.enrolled,
                display: Constants.MDM.Labels.enrolled,
                value: .string(enrolled)
            ),
            (
                key: Constants.MDM.Keys.enrolledDate,
                display: Constants.MDM.Labels.enrolledDate,
                value: .string(enrolledDate)
            )
        ]
    }
}

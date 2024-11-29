//
//  EnforcementStateMessage.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation

struct EnforcementStateMessage: Codable {
    let enforcementState: Int
    let errorCode: Int64
}

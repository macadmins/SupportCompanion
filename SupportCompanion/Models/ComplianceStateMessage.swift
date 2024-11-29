//
//  ComplianceStateMessage.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-25.
//

import Foundation

struct ComplianceStateMessage: Codable {
    let applicability: Int
    let complianceState: Int
    let desiredState: Int
    let errorCode: Int64
    let installContext: Int
    let productVersion: String
    let targetType: Int
}

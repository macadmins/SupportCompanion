//
//  App.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-13.
//

import Foundation

struct IntuneApp: Codable {
    let applicationName: String
    let errorDetails: String?
    let errorCode: Int64
    let intent: Int
    let policyId: String
    let policyType: Int
    let policyVersion: Int
    let complianceStateMessage: ComplianceStateMessage?
    let enforcementStateMessage: EnforcementStateMessage?
}

//
//  ElevationPreferences.swift
//  SupportCompanion
//

import Foundation
import SwiftUI

@MainActor
class ElevationPreferences: ObservableObject {
    @AppStorage("ShowElevateTrayCard") var showElevateTrayCard: Bool = true

    // Elevation grants admin rights, so these are only read from administrator-managed preferences.
    // See TrustedPreferences.
    var enableElevation: Bool { TrustedPreferences.bool(forKey: "EnableElevation", default: false) }
    var maxElevationTime: Int { TrustedPreferences.int(forKey: "MaxElevationTime", default: 5) }
    var requireReasonForElevation: Bool { TrustedPreferences.bool(forKey: "RequireResonForElevation", default: true) }
    var reasonMinLength: Int { TrustedPreferences.int(forKey: "ReasonMinLength", default: 10) }
    var elevationWebhookURL: String { TrustedPreferences.string(forKey: "ElevationWebhookUrl", default: "") }
    var elevationSeverity: Int { TrustedPreferences.int(forKey: "ElevationSeverity", default: 6) }
}

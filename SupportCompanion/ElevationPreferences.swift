//
//  ElevationPreferences.swift
//  SupportCompanion
//

import Foundation
import SwiftUI

class ElevationPreferences: ObservableObject {
    @AppStorage("EnableElevation") var enableElevation: Bool = false
    @AppStorage("ShowElevateTrayCard") var showElevateTrayCard: Bool = true
    @AppStorage("MaxElevationTime") var maxElevationTime: Int = 5
    @AppStorage("RequireResonForElevation") var requireReasonForElevation: Bool = true
    @AppStorage("ReasonMinLength") var reasonMinLength: Int = 10
    @AppStorage("ElevationWebhookUrl") var elevationWebhookURL: String = ""
    @AppStorage("ElevationSeverity") var elevationSeverity: Int = 6
}

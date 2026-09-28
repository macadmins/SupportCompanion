//
//  ElevationPreferences.swift
//  SupportCompanion
//

import Foundation
import Observation

@MainActor
@Observable
class ElevationPreferences {
    var showElevateTrayCard: Bool {
        get { DefaultsStore.value(forKey: "ShowElevateTrayCard", default: true) }
        set { DefaultsStore.set(newValue, forKey: "ShowElevateTrayCard") }
    }

    // Elevation grants admin rights, so these are only read from administrator-managed preferences.
    // See TrustedPreferences.
    var enableElevation: Bool { trusted.bool(forKey: "EnableElevation", default: false) }
    var maxElevationTime: Int { trusted.int(forKey: "MaxElevationTime", default: 5) }
    var requireReasonForElevation: Bool { trusted.bool(forKey: "RequireResonForElevation", default: true) }
    var reasonMinLength: Int { trusted.int(forKey: "ReasonMinLength", default: 10) }
    var elevationWebhookURL: String { trusted.string(forKey: "ElevationWebhookUrl", default: "") }
    var elevationSeverity: Int { trusted.int(forKey: "ElevationSeverity", default: 6) }

    /// TrustedPreferences reads UserDefaults directly, so register the DefaultsStore revision to stay observable
    private var trusted: TrustedPreferences.Type {
        _ = DefaultsStore.shared.revision
        return TrustedPreferences.self
    }
}

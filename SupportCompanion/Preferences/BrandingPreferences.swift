//
//  BrandingPreferences.swift
//  SupportCompanion
//

import Foundation
import Observation

@MainActor
@Observable
class BrandingPreferences {
    var brandName: String {
        get { DefaultsStore.value(forKey: "BrandName", default: "Support Companion") }
        set { DefaultsStore.set(newValue, forKey: "BrandName") }
    }
    var brandLogo: String {
        get { DefaultsStore.value(forKey: "BrandLogo", default: "") }
        set { DefaultsStore.set(newValue, forKey: "BrandLogo") }
    }
    var brandLogoLight: String {
        get { DefaultsStore.value(forKey: "BrandLogoLight", default: "") }
        set { DefaultsStore.set(newValue, forKey: "BrandLogoLight") }
    }
    var accentColor: String? {
        get { DefaultsStore.optionalValue(forKey: "AccentColor") }
        set { DefaultsStore.setOptional(newValue, forKey: "AccentColor") }
    }
}

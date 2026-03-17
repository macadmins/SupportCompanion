//
//  BrandingPreferences.swift
//  SupportCompanion
//

import Foundation
import SwiftUI

class BrandingPreferences: ObservableObject {
    @AppStorage("BrandName") var brandName: String = "Support Companion"
    @AppStorage("BrandLogo") var brandLogo: String = ""
    @AppStorage("BrandLogoLight") var brandLogoLight: String = ""
    @AppStorage("AccentColor") var accentColor: String?
}

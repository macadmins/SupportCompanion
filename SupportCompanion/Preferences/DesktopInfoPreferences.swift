//
//  DesktopInfoPreferences.swift
//  SupportCompanion
//

import Foundation
import Observation

@MainActor
@Observable
class DesktopInfoPreferences {
    var desktopInfoBackgroundOpacity: Double {
        get { DefaultsStore.value(forKey: "DesktopInfoBackgroundOpacity", default: 0.001) }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoBackgroundOpacity") }
    }
    var desktopInfoBackgroundFrosted: Bool {
        get { DefaultsStore.value(forKey: "DesktopInfoBackgroundFrosted", default: false) }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoBackgroundFrosted") }
    }
    var desktopInfoWindowPosition: String {
        get { DefaultsStore.value(forKey: "DesktopInfoWindowPosition", default: "LowerRight") }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoWindowPosition") }
    }
    var showDesktopInfo: Bool {
        get { DefaultsStore.value(forKey: "ShowDesktopInfo", default: false) }
        set { DefaultsStore.set(newValue, forKey: "ShowDesktopInfo") }
    }
    var desktopInfoFontSize: Int {
        get { DefaultsStore.value(forKey: "DesktopInfoFontSize", default: 14) }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoFontSize") }
    }
    var desktopInfoLevel: Int {
        get { DefaultsStore.value(forKey: "DesktopInfoLevel", default: 4) }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoLevel") }
    }
    var desktopInfoHideItems: [String] {
        get { DefaultsStore.value(forKey: "DesktopInfoHideItems", default: []) }
        set { DefaultsStore.set(newValue, forKey: "DesktopInfoHideItems") }
    }
}

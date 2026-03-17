//
//  DesktopInfoPreferences.swift
//  SupportCompanion
//

import Foundation
import SwiftUI
import Combine

class DesktopInfoPreferences: ObservableObject {
    @AppStorage("DesktopInfoBackgroundOpacity") var desktopInfoBackgroundOpacity: Double = 0.001
    @AppStorage("DesktopInfoBackgroundFrosted") var desktopInfoBackgroundFrosted: Bool = false
    @AppStorage("DesktopInfoWindowPosition") var desktopInfoWindowPosition: String = "LowerRight"
    @AppStorage("ShowDesktopInfo") var showDesktopInfo: Bool = false
    @AppStorage("DesktopInfoFontSize") var desktopInfoFontSize: Int = 14
    @AppStorage("DesktopInfoLevel") var desktopInfoLevel: Int = 4

    /// Published mirror of `desktopInfoWindowPosition` so Combine subscribers react to position changes.
    @Published var currentWindowPosition: String = "LowerRight"

    /// Array preference loaded from UserDefaults (AppStorage doesn't support [String]).
    @Published var desktopInfoHideItems: [String] = UserDefaults.standard.array(forKey: "DesktopInfoHideItems") as? [String] ?? []

    private var cancellables = Set<AnyCancellable>()

    init() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.currentWindowPosition = self.desktopInfoWindowPosition
                let latest = UserDefaults.standard.array(forKey: "DesktopInfoHideItems") as? [String] ?? []
                if self.desktopInfoHideItems != latest {
                    self.desktopInfoHideItems = latest
                }
            }
            .store(in: &cancellables)
    }
}

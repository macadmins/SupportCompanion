import SwiftUI
import Foundation
import ServiceManagement

@main
struct SupportCompanion: App {
    
    @StateObject private var appStateManager = AppStateManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
             EmptyView() // Use this to suppress unwanted UI elements like Preferences
        }
    }
}

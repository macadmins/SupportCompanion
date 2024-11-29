import SwiftUI
import Foundation
import ServiceManagement

@main
struct SupportCompanion: App {
    
    @StateObject private var appStateManager = AppStateManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    /*var body: some Scene {
        WindowGroup {
            ContentView()
                .navigationTitle("")
                .ignoresSafeArea(.all)
                .frame(width: 1400, height: 900)
                .environmentObject(appStateManager)
                .onAppear(perform: {
                    Task {
                        appStateManager.refreshAll()  // Ensure asynchronous call is done on launch
                        appStateManager.systemUpdatesManager.startMonitoring()
                    }
                })
                .onDisappear(perform: {
                    appStateManager.systemUpdatesManager.stopMonitoring()
                })
                .hidden()
            }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
    }*/
    
    var body: some Scene {
         Settings {
             EmptyView() // Use this to suppress unwanted UI elements like Preferences
         }
     }
}

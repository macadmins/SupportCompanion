//
//  JsonCardManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-24.
//

import Foundation

class JsonCardManager: ObservableObject {
    private var appState: AppStateManager
    private var fileWatcher: FileWatcher?
    
    init(appState: AppStateManager) {
        self.appState = appState
    }

    func watchFile(_ filePath: String) {
        let expanded = (filePath as NSString).expandingTildeInPath
        let resolved = URL(fileURLWithPath: expanded).resolvingSymlinksInPath().path
        fileWatcher = nil
        Logger.shared.logDebug("JsonCardManager: watching file at \(resolved)")
        fileWatcher = FileWatcher(filePath: resolved) { [weak self] in
            Logger.shared.logDebug("JsonCardManager: file change detected, reloading")
            self?.loadFromFile(resolved)
        }
    }
    
    func loadFromFile(_ fileName: String) {
        let expanded = (fileName as NSString).expandingTildeInPath
        let fileURL = URL(fileURLWithPath: expanded).resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.shared.logDebug("Custom Card File not found: \(fileURL.path)")
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decodedCards = try JSONDecoder().decode([JsonCard].self, from: data)
            DispatchQueue.main.async {
                self.appState.JsonCards = decodedCards
            }
        } catch {
            Logger.shared.logError("Failed to load cards: \(error.localizedDescription)")
        }
    }
    
    func stopWatching() {
        fileWatcher = nil
    }
}

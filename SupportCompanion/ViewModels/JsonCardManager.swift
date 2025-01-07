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
        fileWatcher = FileWatcher(filePath: filePath) { [weak self] in
            self?.loadFromFile(filePath)
        }
    }
    
    func loadFromFile(_ fileName: String) {
        let fileURL = URL(fileURLWithPath: fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            Logger.shared.logDebug("Csutom Card File not found: \(fileURL.path)")
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
}

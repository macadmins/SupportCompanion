//
//  EvergreenInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-28.
//

import Foundation

class EvergreenInfoManager: ObservableObject {
    private var evergreenHelper = EvergreenHelpers()
    private var appState: AppStateManager
    
    init(appState: AppStateManager) {
        self.appState = appState
    }
    
    func refresh() {
        Task {
            await updateEvergreenInfo()
        }
    }
    
    func updateEvergreenInfo() async {
        let catalogs = await evergreenHelper.getCatalogs()
        DispatchQueue.main.async {
            self.appState.catalogs = Array(Set(catalogs))
        }
    }
}

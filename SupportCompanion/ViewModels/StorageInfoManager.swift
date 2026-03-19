//
//  StorageInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import Combine
import SwiftUI

@MainActor
class StorageInfoManager: ObservableObject {
    static let shared = StorageInfoManager(
        storageInfo: StorageInfo(
            id: UUID(),
            name: getStorageName(),
            fileVault: isFileVaultEnabled(),
            usage: getStorageUsagePercentage()
        )
    )
    
    @Published var storageInfo: StorageInfo

    init(storageInfo: StorageInfo) {
        self.storageInfo = storageInfo
    }
    
    func startMonitoring() {
        self.updateStorageInfo()
        
        StorageMonitor.shared.startMonitoring { [weak self] usagePercentage in
            guard let self = self else { return }
            self.updateStorageInfo(usagePercentage: usagePercentage)
        }
    }

    func stopMonitoring() {
        StorageMonitor.shared.stopMonitoring()
    }
    
    func refresh() {
        self.updateStorageInfo()
    }
    
    func updateStorageInfo(usagePercentage: Double = getStorageUsagePercentage()) {
        self.storageInfo = StorageInfo(
            id: UUID(),
            name: getStorageName(),
            fileVault: isFileVaultEnabled(),
            usage: usagePercentage
        )
    }
}

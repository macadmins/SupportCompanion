//
//  StorageInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation
import Combine
import SwiftUI

class StorageInfoManager: ObservableObject {
    @Environment(\.colorScheme) var colorScheme
    
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
    
    func getPercentageColor(percentage: Double) -> Color {
        if percentage < 50 {
            return .ScGreen
        } else if percentage < 80 {
            return colorScheme == .light ? .orangeLight : .orange
        } else {
            return colorScheme == .light ? .redLight : .red
        }
    }
    
    func updateStorageInfo(usagePercentage: Double = getStorageUsagePercentage()) {
        DispatchQueue.main.async {
            self.storageInfo = StorageInfo(
                id: UUID(),
                name: getStorageName(),
                fileVault: isFileVaultEnabled(),
                usage: usagePercentage
            )
        }
    }
}

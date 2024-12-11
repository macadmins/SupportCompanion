//
//  StorageDeviceManagementStack.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct StorageDeviceManagementStack: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        if !viewModel.isCardVisible(Constants.Cards.storage) && !viewModel.isCardVisible(Constants.Cards.deviceManagement) {
        } else{
            VStack(alignment: .leading){
                // Storage Card
                if viewModel.isCardVisible(Constants.Cards.storage) {
                    ScCard(title: "\(Constants.CardTitle.storage)",
                               titleImageName: "internaldrive.fill",
                               buttonImageName: "macwindow.on.rectangle",
                               buttonAction: { viewModel.openStoragePanel() },
                               buttonHelpText: Constants.ToolTips.openStoragePanel,
                               content:  {
                        VStack(alignment: .leading, spacing: 5) {
                            CardData(
                                info: appState.storageInfoManager.storageInfo.toKeyValuePairs(),
                                customContent: { key, value in
                                    if key == "FileVault" {
                                        return AnyView(
                                            ProgressView(
                                                value: appState.storageInfoManager.storageInfo.usage,
                                                total: 100,
                                                label: {
                                                    Text("\(String(format: "%.1f", appState.storageInfoManager.storageInfo.usage))% Used")
                                                    .font(.system(size: 14))}
                                            )
                                            .tint(appState.storageInfoManager.storageInfo.usage < 50 ? .ScGreen
                                                  : appState.storageInfoManager.storageInfo.usage < 80 ? (colorScheme == .light ? .orangeLight : .orange)
                                                  : (colorScheme == .light ? .redLight : .red))
                                            .padding(.top)
                                        )
                                    }
                                    return AnyView(EmptyView())
                                }
                            )
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    })
                }
                
                // Device Management Card
                if viewModel.isCardVisible(Constants.Cards.deviceManagement) {
                    ScCard(title: "\(Constants.CardTitle.deviceManagement)", titleImageName: "lock.shield", content:  {
                        VStack(alignment: .leading, spacing: 5) {
                            CardData(info: appState.mdmInfoManager.mdmInfo.toKeyValuePairs())
                        }
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    })
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

//
//  BatteryEvergreenStack.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation
import SwiftUI

struct BatteryEvergreenStack: View {
    @ObservedObject var viewModel: CardGridViewModel
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        if !viewModel.isCardVisible("Evergreen") && !viewModel.isCardVisible("Battery") {
        } else{
            VStack(alignment: .leading){
                if viewModel.isCardVisible("Evergreen") && appState.preferences.mode == Constants.modes.munki {
                    CustomCard(title: "\(Constants.CardTitle.evergreen)", titleImageName: "leaf.fill", content: {
                        VStack(alignment: .leading) {
                            Text("Rings")
                                .font(.system(size: 14))
                            Divider()
                                .padding(.top)
                                .padding(.bottom)
                            VStack(alignment: .leading) {
                                ForEach(appState.catalogs.indices, id: \.self) { index in
                                    Text(appState.catalogs[index])
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .onAppear {
                            appState.evergreenInfoManager.refresh()
                        }
                    })
                }
                
                if viewModel.isCardVisible("Battery") {
                    CustomCard(title: "\(Constants.CardTitle.battery)", titleImageName: "battery.100percent.bolt", imageSize: (25,25), content: {
                        VStack(alignment: .leading) {
                            CardData(info: appState.batteryInfoManager.batteryInfo.toKeyValuePairs())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .onAppear {
                            appState.batteryInfoManager.startMonitoring()
                        }
                        .onDisappear {
                            appState.batteryInfoManager.stopMonitoring()
                        }
                        .onChange(of: appState.windowIsVisible) { oldValue, newValue in
                            if !newValue {
                                appState.batteryInfoManager.stopMonitoring()
                            }
                        }
                    }
                )}
            }
        }
    }
}

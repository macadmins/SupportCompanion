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
        if !viewModel.isCardVisible(Constants.Cards.evergreen) && !viewModel.isCardVisible(Constants.Cards.battery) {
        } else{
            VStack(alignment: .leading){
                if viewModel.isCardVisible(Constants.Cards.battery) {
                    ScCard(title: "\(Constants.CardTitle.battery)", titleImageName: "battery.100percent.bolt", imageSize: (25,25), content: {
                        VStack(alignment: .leading) {
                            CardData(info: appState.batteryInfoManager.batteryInfo.toKeyValuePairs())
                        }
                        .frame(height: 110)
                        .padding(.horizontal)
                    }
                )
                .fixedSize(horizontal: false, vertical: true)
                }
                
                if viewModel.isCardVisible(Constants.Cards.evergreen) && appState.preferences.mode == Constants.modes.munki {
                    ScCard(title: "\(Constants.CardTitle.evergreen)", titleImageName: "leaf.fill", content: {
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
                        .frame(height: 116)
                        .padding(.horizontal)
                    })
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

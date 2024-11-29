//
//  PSSOCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-27.
//

import Foundation

import SwiftUI

struct PSSOCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading){
            if "" != appState.ssoInfoManager.platformSSO.loginType {
                CustomCard(title: "\(Constants.CardTitle.platformSSO)", titleImageName: "lock.fill", content: {
                        VStack(alignment: .leading) {
                            CardData(info: appState.ssoInfoManager.platformSSO.toKeyValuePairs())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                )
            }
        }
    }
}

//
//  IdentityCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct KSSOCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading){
            if "" != appState.ssoInfoManager.kerberosSSO.username {
                CustomCard(title: "\(Constants.CardTitle.kerberosSSO)", titleImageName: "lock.fill", useMultiColor: false, content: {
                        VStack(alignment: .leading) {
                            CardData(info: appState.ssoInfoManager.kerberosSSO.toKeyValuePairs())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                )
            }
        }
    }
}

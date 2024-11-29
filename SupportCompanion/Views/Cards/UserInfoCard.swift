//
//  UserInfoCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct UserInfoCard: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading){
            CustomCard(title: "\(Constants.CardTitle.userInfo)", titleImageName: "person.fill", content: {
                    VStack(alignment: .leading) {
                        CardData(info: appState.userInfoManager.userInfo.toKeyValuePairs())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
            )
        }
    }
}

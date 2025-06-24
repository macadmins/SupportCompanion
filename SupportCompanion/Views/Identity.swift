//
//  Identity.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct Identity: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ZStack{
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading
                ) {
                    UserInfoCard()
                    if !appState.ssoInfoManager.kerberosSSO.realm.isEmpty {
                        KSSOCard()
                    }
                    if !appState.ssoInfoManager.platformSSO.loginType.isEmpty {
                        PSSOCard()
                    }
                    if appState.preferences.enableElevation {
                        ElevationCard()
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
                //.padding(.top, 20)
            }
            .onAppear {
                appState.userInfoManager.refresh()
                Task {
                    do {
                       await appState.ssoInfoManager.refresh()
                    }
                }
            }
        }
    }
}

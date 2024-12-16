//
//  UserInfoCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct ElevationCard: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var showReasonInput = false
    @State private var elevationReason = ""

    var body: some View {
        let elevationManager = ElevationManager(appState: appState)

        VStack(alignment: .leading) {
            ScCard(title: Constants.CardTitle.privileges, titleImageName: "lock.fill", useMultiColor: false, content: {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Revocation in: ")
                            .bold()
                            .font(.system(size: 14))
                        if appState.timeToDemote > 0 {
                            Text(appState.timeToDemote.formattedTime())
                                .foregroundColor(.red)
                                .font(.system(size: 14))
                        }
                    }

                    Spacer()

                    ScButton(Constants.General.elevate, disabled: appState.userInfoManager.userInfo.isAdmin || appState.isDemotionActive) {
                        if appState.preferences.requireReasonForElevation {
                            showReasonInput = true // Show reason input modal
                        } else {
                            elevationManager.handleElevation(reason: "")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            })
        }
        .sheet(isPresented: $showReasonInput) {
            ReasonInputView(isPresented: $showReasonInput, onElevate: elevationManager.handleElevation)
        }
    }
}

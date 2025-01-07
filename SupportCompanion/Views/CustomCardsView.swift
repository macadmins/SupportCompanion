//
//  JsonCardView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-12-22.
//

import Foundation
import SwiftUI

struct CustomCardsView: View {
    @EnvironmentObject var appState: AppStateManager
    
    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 300))]
        ZStack{
            ScrollView {
                LazyVGrid(
                    columns: columns,
                    alignment: .leading
                ) {
                    if appState.JsonCards.count > 0 {
                        ForEach(appState.JsonCards) { card in
                            JsonCardView(card: card)
                        }
                    }
                }
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
        }
        .onAppear {
            if appState.JsonCards.isEmpty {
                appState.refreshJsonCards()
            }
        }
    }
}

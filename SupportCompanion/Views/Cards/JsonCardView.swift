//
//  JsonCardView.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-24.
//

import Foundation
import SwiftUI

struct JsonCardView: View {
    let card: JsonCard

    var body: some View {
        ScCard(
            title: card.header,
            titleImageName: card.icon,
            content: {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(card.data.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text("\(key):")
                                .bold()
                            Text(value)
                        }
                        .font(.system(size: 14))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
        )
    }
}

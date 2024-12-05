//
//  Card.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

struct Card: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let description: String
}

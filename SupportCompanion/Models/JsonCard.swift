//
//  JsonCard.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-24.
//

import Foundation

struct JsonCard: Identifiable, Codable {
    let id = UUID()
    let icon: String
    let header: String
    let data: [String: String]
    
    enum CodingKeys: String, CodingKey {
        case icon
        case header = "Header"
        case data
    }
}

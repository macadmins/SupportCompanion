//
//  InfoValue.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-15.
//

import Foundation

extension InfoValue {
    func asString() -> String? {
        if case let .string(value) = self {
            return value
        }
        return nil
    }

    func asDouble() -> Double? {
        if case let .double(value) = self {
            return value
        }
        return nil
    }

    func asInt() -> Int? {
        if case let .int(value) = self {
            return value
        }
        return nil
    }
    
    func toUpper() -> InfoValue {
        switch self {
        case .string(let value):
            return .string(value.uppercased())
        default:
            return self
        }
    }
}

enum InfoValue {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)
    case none
    
    // Convert to a displayable string
    var displayValue: String {
        switch self {
        case .string(let value):
            return value
        case .double(let value):
            return String(format: "%.1f", value)
        case .int(let value):
            return "\(value)"
        case .bool(let value):
            return value ? "Enabled" : "Disabled"
        case .none:
            return ""
        }
    }
    
    // Returns the raw value for specific types (useful for logic).
    var rawValue: Any {
        switch self {
        case .string(let value):
            return value
        case .double(let value):
            return value
        case .int(let value):
            return value
        case .bool(let value):
            return value
        case .none:
            return true
        }
    }
    
    var isEmpty: Bool {
        switch self {
        case .string(let value):
            return value.isEmpty
        case .double:
            return false // Doubles are never empty
        case .int:
            return false // Integers are never empty
        case .bool:
            return false // Booleans are never empty
        case .none:
            return true // None is always considered empty
        }
    }
}

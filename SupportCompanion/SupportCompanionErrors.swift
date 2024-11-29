//
//  SupportCompanionErrors.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

// MARK: - ScriptexError

/// Errors that can be thrown in this project.
enum SupportCompanionErrors {

    case invalidStringConversion
    case helperInstallation(String)
    case helperConnection(String)
    case unknown
}

// MARK: - LocalizedError

extension SupportCompanionErrors: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .invalidStringConversion: return "The output data is not convertible to a String (utf8)"
        case .helperInstallation(let description): return "Helper installation error. \(description)"
        case .helperConnection(let description): return "Helper connection error. \(description)"
        case .unknown: return "Unknown error"
        }
    }
}

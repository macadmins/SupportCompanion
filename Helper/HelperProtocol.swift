//
//  HelperProtocol.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

@objc(HelperProtocol)
public protocol HelperProtocol {
    @objc func executeScript(at path: String) async throws -> String
    @objc func executeCommand(_ command: String, with arguments: [String]) async throws -> String
}

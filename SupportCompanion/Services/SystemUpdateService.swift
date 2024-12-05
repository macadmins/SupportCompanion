//
//  SystemUpdateService.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-19.
//

import Foundation

struct SystemUpdateService {
    static func fetchSystemUpdates() async -> Result<(Int, [String]), Error> {
        do {
            let result = try await ExecutionService.executeCommand("/usr/sbin/softwareupdate", with: ["-l"])
            let lines = result.split(whereSeparator: \.isNewline)
            
            let updates = lines.filter { $0.contains("*") }.map { String($0) }
            return .success((updates.count, updates))
        } catch {
            return .failure(error)
        }
    }
}

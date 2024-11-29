//
//  UserHelpers.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

class UserInfoHelper {
    private let loginNamePattern = #"Login: (\S+)"#
    private let namePattern = #"Name: (.+)"#
    private let homeDirPattern = #"Directory: (\S+)"#
    private let shellPattern = #"Shell: (\S+)"#

    func fetchUserInfo() async throws -> UserInfo {
        // Get the current username
        let currentUser = NSUserName() // Fetches the current login username

        // Fetch basic user info with `finger`
        let userOutput = try await ExecutionService.executeCommand("/usr/bin/finger", with: [currentUser])

        guard !userOutput.isEmpty else {
            throw NSError(domain: "UserInfoHelper", code: -1, userInfo: [NSLocalizedDescriptionKey: "No output from finger command"])
        }

        // Extract user information using regex patterns
        let login = extractMatch(from: userOutput, with: loginNamePattern) ?? currentUser
        let name = extractMatch(from: userOutput, with: namePattern) ?? "Unknown"
        let homeDir = extractMatch(from: userOutput, with: homeDirPattern) ?? "Unknown"
        let shell = extractMatch(from: userOutput, with: shellPattern) ?? "Unknown"

        // Check admin status with `dscl`
        let isAdmin = try await checkAdminStatus(for: login)

        return UserInfo(login: login, name: name, homeDir: homeDir, shell: shell, isAdmin: isAdmin)
    }

    private func extractMatch(from text: String, with pattern: String) -> String? {
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex?.firstMatch(in: text, options: [], range: range),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range])
    }

    private func checkAdminStatus(for user: String) async throws -> Bool {
        let adminGroupOutput = try await ExecutionService.executeCommand("/usr/bin/dscl", with: [".", "-read", "/Groups/admin", "GroupMembership"])
        return adminGroupOutput.contains(user)
    }
}

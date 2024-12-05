//
//  UserInfo.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

struct UserInfo {
    let login: String
    let name: String
    let homeDir: String
    let shell: String
    let isAdmin: Bool
    
    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: Constants.UserInfo.Keys.username,
                display: Constants.UserInfo.Labels.username,
                value: .string(login)
            ),
            (
                key: Constants.UserInfo.Keys.name,
                display: Constants.UserInfo.Labels.name,
                value: .string(name)
            ),
            (
                key: Constants.UserInfo.Keys.homeDir,
                display: Constants.UserInfo.Labels.homeDir,
                value: .string(homeDir)
            ),
            (
                key: Constants.UserInfo.Keys.shell,
                display: Constants.UserInfo.Labels.shell,
                value: .string(shell)
            ),
            (
                key: Constants.UserInfo.Keys.isAdmin,
                display: Constants.UserInfo.Labels.isAdmin,
                value: .bool(isAdmin)
            )
        ]
    }
}

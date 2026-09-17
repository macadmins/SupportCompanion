//
//  UserInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import Observation

@MainActor
@Observable
class UserInfoManager {
    static let shared = UserInfoManager(
        userInfo: UserInfo(
            login: "",
            name: "",
            homeDir: "",
            shell: "",
            isAdmin: false
        )
    )
    
    var userInfo: UserInfo
    
    private let helper = UserInfoHelper()
    
    init(userInfo: UserInfo) {
        self.userInfo = userInfo
    }
    
    func refresh() {
        updateUserInfo()
    }
    
    func updateUserInfo() {
        Task {
            let userDetails = try await helper.fetchUserInfo()
            self.userInfo = userDetails
        }
    }
}

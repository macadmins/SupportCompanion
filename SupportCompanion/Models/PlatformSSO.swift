//
//  PlatformSSO.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation
import SwiftUI

struct PlatformSSO {
    
    let id: UUID
    let loginFrequency: Int
    let loginType: String
    let newUserAuthorizationMode: String
    let registrationCompleted: Bool
    let sdkVersionString: String
    let sharedDeviceKeys: Bool
    let userAuthorizationMode: String
    
    var registrationColor: Color {
        if registrationCompleted == true {
            return .ScGreen
        } else {
            return Color(NSColor.red)
        }
    }

    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: Constants.PlatformSSO.Keys.loginFrequency,
                display: Constants.PlatformSSO.Labels.loginFrequency,
                value: .int(loginFrequency)
            ),
            (
                key: Constants.PlatformSSO.Keys.loginType,
                display: Constants.PlatformSSO.Labels.loginType,
                value: .string(loginType)
            ),
            (
                key: Constants.PlatformSSO.Keys.newUserAuthorizationMode,
                display: Constants.PlatformSSO.Labels.newUserAuthorizationMode,
                value: .string(newUserAuthorizationMode)
            ),
            (
                key: Constants.PlatformSSO.Keys.registrationCompleted,
                display: Constants.PlatformSSO.Labels.registrationCompleted,
                value: .bool(registrationCompleted)
            ),
            (
                key: Constants.PlatformSSO.Keys.sdkVersionString,
                display: Constants.PlatformSSO.Labels.sdkVersionString,
                .string(sdkVersionString)
            ),
            (
                key: Constants.PlatformSSO.Keys.sharedDeviceKeys,
                display: Constants.PlatformSSO.Labels.sharedDeviceKeys,
                value: .bool(sharedDeviceKeys)
            ),
            (
                key: Constants.PlatformSSO.Keys.userAuthorizationMode,
                display: Constants.PlatformSSO.Labels.userAuthorizationMode,
                value: .string(userAuthorizationMode)
            )
        ]
    }
}

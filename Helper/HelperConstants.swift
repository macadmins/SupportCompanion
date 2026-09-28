//
//  HelperConstants.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-12.
//

import Foundation

enum HelperConstants {
    static let helpersFolder = "/Library/PrivilegedHelperTools/"
    static let domain = "com.github.macadmins.SupportCompanion.helper"
    static let helperPath = helpersFolder + domain
    
    static let bundleID = "com.github.macadmins.SupportCompanion"
    static let appPath = "/Applications/SupportCompanion.app"

    /// The oldest client this helper will serve.
    ///
    /// 2.x honored `IsPrivileged` from preference domains a standard user can write, so a copy of one
    /// kept on disk was enough to reach this helper and get root. Compared component by component, so a
    /// four-component build version such as `3.0.0.81132` satisfies a three-component minimum.
    ///
    /// Deliberately the marketing version and not a build number: the build suffix comes from
    /// `git rev-list --count`, which drops if history is ever rewritten, and a floor above the version
    /// a later build reports would make the helper refuse its own app. Raise this only when a release
    /// fixes a privilege check that lives in the app.
    static let minimumClientVersion = "3.0.0"
    static let debugSubject = "\"42EJ7ZYMPQ\""
    static let subject = "\"T4SK8ZXCXG\""
}

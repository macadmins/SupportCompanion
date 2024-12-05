//
//  KerberosSSO.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

struct KerberosSSO {
    
    let id: UUID
    let expiryDays: Int
    let lastSSOPasswordChangeDays: Int
    let realm: String
    let lastLocalPasswordChangeDays: Int
    let username: String

    func toKeyValuePairs() -> [(key: String, display: String, value: InfoValue)] {
        return [
            (
                key: Constants.KerberosSSO.Keys.expiryDays,
                display: Constants.KerberosSSO.Labels.exipiryDays,
                value: .int(expiryDays)
            ),
            (
                key: Constants.KerberosSSO.Keys.lastSSOPasswordChangeDays,
                display: Constants.KerberosSSO.Labels.lastSSOPasswordChangeDays,
                value: .int(lastSSOPasswordChangeDays)
            ),
            (
                key: Constants.KerberosSSO.Keys.realm,
                display: NSLocalizedString("Realm:", comment: ""),
                value: .string(realm)
            ),
            (
                key: Constants.KerberosSSO.Keys.lastLocalPasswordChangeDays,
                display: Constants.KerberosSSO.Labels.lastLocalPasswordChangeDays,
                value: .int(lastLocalPasswordChangeDays)
            ),
            (
                key: Constants.KerberosSSO.Keys.kerberosSSOUsername,
                display: Constants.KerberosSSO.Labels.kerberosSSOUsername,
                value: .string(username)
            )
        ]
    }
}

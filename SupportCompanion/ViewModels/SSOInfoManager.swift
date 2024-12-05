//
//  SSOInfoManager.swift
//  SupportCompanion
//
//  Created by Tobias Almén on 2024-11-20.
//

import Foundation

class SSOInfoManager: ObservableObject {
    static let shared = SSOInfoManager(
        kerberosSSO: KerberosSSO(
            id: UUID(),
            expiryDays: 0,
            lastSSOPasswordChangeDays: 0,
            realm: "",
            lastLocalPasswordChangeDays: 0,
            username: ""
        ),
        platformSSO: PlatformSSO(
            id: UUID(),
            loginFrequency: 0,
            loginType: "",
            newUserAuthorizationMode: "",
            registrationCompleted: false,
            sdkVersionString: "",
            sharedDeviceKeys: false,
            userAuthorizationMode: ""
        )
    )

    @Published var kerberosSSO: KerberosSSO
    @Published var platformSSO: PlatformSSO

    private let helper = SSOInfoHelpers()

    init(kerberosSSO: KerberosSSO, platformSSO: PlatformSSO) {
        self.kerberosSSO = kerberosSSO
        self.platformSSO = platformSSO
    }

    func setup() {
        Task {
            await refresh() // Perform initial refresh after initialization
        }
    }

    func refresh() async {
        do {
            let realmName = await helper.fetchRealm()
            let psso = await helper.fetchPlatformSSOCheckOnly()

            if realmName.isEmpty {
                Logger.shared.logDebug("realm name is empty, refreshing platform SSO")
                await updatePlatformSSO()
            } else {
                await updateKerberosSSO()
                if psso {
                    await updatePlatformSSO()
                }
            }
        } catch {
            Logger.shared.logError("Failed to refresh SSO Info: \(error.localizedDescription)")
        }
    }

    private func updateKerberosSSO() async {
        do {
            let kerberosDetails = try await helper.fetchKerberosSSO()
            DispatchQueue.main.async {
                self.kerberosSSO = kerberosDetails
            }
        } catch {
            Logger.shared.logError("Failed to update Kerberos SSO Info: \(error.localizedDescription)")
        }
    }

    private func updatePlatformSSO() async {
        do {
            let platformDetails = try await helper.fetchPlatformSSO()
            DispatchQueue.main.async {
                self.platformSSO = platformDetails
            }
        } catch {
            Logger.shared.logError("Failed to update Platform SSO Info: \(error.localizedDescription)")
        }
    }
}

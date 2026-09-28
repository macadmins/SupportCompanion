//
//  FleetSSOSessionStore.swift
//  SupportCompanion
//
//  Keychain storage for the Fleet Desktop SSO session.
//
//  The cookie Fleet issues after sign-in is a bearer credential for this Mac's device API and lasts
//  for the server's `session.duration` (5 days by default), so it's kept in the keychain rather than
//  in defaults, and it's scoped to the host that issued it: a Mac repointed at another Fleet server
//  signs in again instead of sending the old server's session to the new one.
//

import Foundation
import Security

enum FleetSSOSessionStore {
    struct Session: Codable, Sendable, Equatable {
        let cookie: String
        /// Host of the Fleet server that issued it.
        let host: String
        /// When Fleet's cookie expires, or nil if it came without a Max-Age.
        let expiresAt: Date?

        /// Whether the session can still be used against `host`, with a minute of slack so a session
        /// about to expire isn't sent only to come back as an SSO prompt.
        func isUsable(on host: String, now: Date = Date()) -> Bool {
            guard self.host.caseInsensitiveCompare(host) == .orderedSame else { return false }
            guard let expiresAt else { return true }
            return expiresAt > now.addingTimeInterval(60)
        }
    }

    private static let service = "com.github.macadmins.SupportCompanion.fleet-sso"
    private static let account = "device-session"

    static func save(_ session: Session) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        // NOTE: this lands in the file-based login keychain, where `kSecAttrAccessible` is ignored --
        // it only takes effect in the data protection keychain, which needs
        // `kSecUseDataProtectionKeychain` and a keychain-access-group entitlement. So the intent below
        // is NOT enforced: the session is readable whenever the login keychain is unlocked, and it can
        // travel to another Mac in a backup or a migration. What actually guards it is the login
        // keychain's ACL, which limits reads to this app's code signature.
        //
        // Accepted deliberately: the credential is a bearer token scoped to this Mac's Fleet device
        // API and expires in 5 days. Revisit if that scope grows.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemUpdate(query() as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query()
            item.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            if addStatus != errSecSuccess {
                Logger.shared.logError("Fleet: couldn't store the SSO session (\(addStatus))")
            }
        } else if status != errSecSuccess {
            Logger.shared.logError("Fleet: couldn't update the SSO session (\(status))")
        }
    }

    /// The stored session if it's still usable on `host`, clearing it when it isn't.
    static func load(host: String) -> Session? {
        var item = query()
        item[kSecReturnData as String] = true
        item[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(item as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            if status != errSecItemNotFound {
                Logger.shared.logError("Fleet: couldn't read the SSO session (\(status))")
            }
            return nil
        }
        guard let session = try? JSONDecoder().decode(Session.self, from: data) else {
            clear()
            return nil
        }
        guard session.isUsable(on: host) else {
            clear()
            return nil
        }
        return session
    }

    static func clear() {
        let status = SecItemDelete(query() as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            Logger.shared.logError("Fleet: couldn't clear the SSO session (\(status))")
        }
    }

    private static func query() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}

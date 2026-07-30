import Foundation
import Security

struct WordPressSyncCredentials: Codable, Equatable {
    var siteURL: String
    var username: String
    var applicationPassword: String
}

enum WordPressSyncCredentialsError: Error {
    case keychainError(OSStatus)
}

final class WordPressSyncCredentialsStore {
    private let service: String
    private let account = "wordpress-sync"

    init(service: String = "Team-Paraiso.CozumelManager.wordpress-sync") {
        self.service = service
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // Scopes the item to this app's Data Protection Keychain access group instead of
            // the legacy file-based keychain, which otherwise lets any unsandboxed process
            // running as the same user read it back via `security find-generic-password -w`.
            kSecUseDataProtectionKeychain as String: true
        ]
    }

    func save(_ credentials: WordPressSyncCredentials) throws {
        let data = try JSONEncoder().encode(credentials)
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw WordPressSyncCredentialsError.keychainError(status)
        }
    }

    func load() -> WordPressSyncCredentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(WordPressSyncCredentials.self, from: data)
    }

    func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

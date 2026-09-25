import Foundation
import Security

protocol TraktTokenStorage {
    func read() throws -> Data?
    func save(_ data: Data) throws
    func delete() throws
}

struct TraktKeychain: TraktTokenStorage {
    private var query: [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.veyra.trakt",
            kSecAttrAccount as String: "oauth"
        ]
        // Gedeeld met de VeyraTopShelf-extensie (zie
        // VeyraKeychainAccessGroup) zodat "Verder kijken" op het
        // tvOS-beginscherm dezelfde Trakt-sessie kan lezen als de app
        // zelf, zonder dat de app open hoeft te staan.
        if let group = VeyraKeychainAccessGroup.shared {
            q[kSecAttrAccessGroup as String] = group
        }
        return q
    }
    func read() throws -> Data? {
        var attributes = query
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw TraktError.storage }
        return result as? Data
    }
    func save(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let added = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
            guard added == errSecSuccess else { throw TraktError.storage }
        } else if status != errSecSuccess { throw TraktError.storage }
    }
    func delete() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw TraktError.storage }
    }
}

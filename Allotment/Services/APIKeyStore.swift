import Foundation
import Security

protocol APIKeyStoring: Sendable {
    func load() -> String?
    func save(_ apiKey: String) throws
    func delete() throws
}

struct APIKeyStore: APIKeyStoring, Sendable {
    private let service = "com.interactivebuffoonery.allotment"
    private let account: String

    init(provider: Provider) {
        account = "apikey.\(provider.rawValue)"
    }

    func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data
        else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func save(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item.merge(attributes) { _, new in new }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else {
                throw KeyStoreError.writeFailed
            }
        } else if status != errSecSuccess {
            throw KeyStoreError.writeFailed
        }
    }

    func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeyStoreError.deleteFailed
        }
    }
}

enum KeyStoreError: LocalizedError {
    case writeFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .writeFailed: "Allotment couldn’t securely save the API key."
        case .deleteFailed: "Allotment couldn’t remove the API key from this device."
        }
    }
}

import Foundation
import Security

enum KeychainAPIKeyStore {
    private static let service = Bundle.main.bundleIdentifier ?? "com.fatlosstracker.app"
    private static let account = "ai-api-key"

    static func read() throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return value
    }

    static func save(_ value: String) throws {
        guard !value.isEmpty else {
            try delete()
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8)
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var newItem = query
        newItem[kSecValueData as String] = Data(value.utf8)
        newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let addStatus = SecItemAdd(newItem as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    static func delete() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }
}

private enum KeychainError: LocalizedError {
    case status(OSStatus)
    case invalidData

    init(status: OSStatus) {
        self = .status(status)
    }

    var errorDescription: String? {
        switch self {
        case .status(let status):
            return SecCopyErrorMessageString(status, nil) as String? ?? "钥匙串错误（\(status)）"
        case .invalidData:
            return "钥匙串中的 API Key 格式无效"
        }
    }
}

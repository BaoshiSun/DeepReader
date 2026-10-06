// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Security

public protocol Credentials {
    func read(_ provider: Provider) throws -> String
    func save(_ value: String, for provider: Provider) throws
    func remove(_ provider: Provider) throws
}

public final class KeychainCredentials: Credentials {
    private let service: String
    public init(service: String = "org.deepreader.macos.providers") { self.service = service }
    private func query(_ provider: Provider) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: provider.rawValue]
    }
    public func read(_ provider: Provider) throws -> String {
        var q = query(provider); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
            throw ReaderError("无法读取钥匙串中的 API Key。请检查系统授权。", "Could not read the API key from Keychain. Check system access permissions.")
        }
        return text
    }
    public func save(_ value: String, for provider: Provider) throws {
        guard Settings.validKey(value) else { throw ReaderError("API Key 格式无效。", "Invalid API key format.") }
        let q = query(provider), attributes = [kSecValueData as String: Data(value.utf8)]
        var status = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = q; add[kSecValueData as String] = Data(value.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ReaderError("API Key 未能保存到钥匙串。", "Could not save the API key in Keychain.") }
    }
    public func remove(_ provider: Provider) throws {
        let status = SecItemDelete(query(provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ReaderError("无法删除已保存的密钥。", "Could not remove the saved key.") }
    }
}

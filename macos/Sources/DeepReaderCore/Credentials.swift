// SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Security
import CryptoKit

public protocol Credentials {
    func read(_ provider: Provider) throws -> String
    func save(_ value: String, for provider: Provider) throws
    func remove(_ provider: Provider) throws
    func read(_ settings: Settings) throws -> String
    func save(_ value: String, for settings: Settings) throws
    func remove(_ settings: Settings) throws
}

public extension Credentials {
    // Legacy test/alternative stores cannot silently reuse keys at a different endpoint.
    func read(_ settings: Settings) throws -> String { try requireDefault(settings); return try read(settings.provider) }
    func save(_ value: String, for settings: Settings) throws { try requireDefault(settings); try save(value, for: settings.provider) }
    func remove(_ settings: Settings) throws { try requireDefault(settings); try remove(settings.provider) }
    private func requireDefault(_ settings: Settings) throws {
        guard settings.endpointText == settings.provider.endpoint.absoluteString else {
            throw ReaderError("密钥存储不支持此自定义地址。", "This credential store does not support a custom endpoint.")
        }
    }
}

public final class KeychainCredentials: Credentials {
    private let service: String
    public init(service: String = "org.deepreader.macos.providers") { self.service = service }
    private func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    private func account(_ settings: Settings) throws -> String {
        // Storage access must still permit removing credentials from older editions.
        let endpoint = try settings.requestEndpoint(appStore: false).absoluteString
        if endpoint == settings.provider.endpoint.absoluteString && settings.provider != .custom { return settings.provider.rawValue }
        let hash = SHA256.hash(data: Data(endpoint.utf8)).map { String(format: "%02x", $0) }.joined()
        return settings.provider.rawValue + ":" + hash
    }
    public func read(_ provider: Provider) throws -> String { try readAccount(provider.rawValue) }
    public func save(_ value: String, for provider: Provider) throws { try saveAccount(value, account: provider.rawValue) }
    public func remove(_ provider: Provider) throws { try removeAccount(provider.rawValue) }
    public func read(_ settings: Settings) throws -> String { try readAccount(account(settings)) }
    public func save(_ value: String, for settings: Settings) throws { try saveAccount(value, account: account(settings)) }
    public func remove(_ settings: Settings) throws { try removeAccount(account(settings)) }
    private func readAccount(_ account: String) throws -> String {
        var q = query(account); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(q as CFDictionary, &result)
        if status == errSecItemNotFound { return "" }
        guard status == errSecSuccess, let data = result as? Data, let text = String(data: data, encoding: .utf8) else {
            throw Self.failure(status == errSecSuccess ? errSecDecode : status, "无法读取钥匙串中的 API Key。", "Could not read the API key from Keychain.")
        }
        return text
    }
    private func saveAccount(_ value: String, account: String) throws {
        guard Settings.validKey(value) else { throw ReaderError("API Key 格式无效。", "Invalid API key format.") }
        let q = query(account), attributes = [kSecValueData as String: Data(value.utf8)]
        var status = SecItemUpdate(q as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var add = q; add[kSecValueData as String] = Data(value.utf8)
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw Self.failure(status, "API Key 未能保存到钥匙串。", "Could not save the API key in Keychain.") }
    }
    private func removeAccount(_ account: String) throws {
        let status = SecItemDelete(query(account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw Self.failure(status, "无法删除已保存的密钥。", "Could not remove the saved key.") }
    }
    static func failure(_ status: OSStatus, _ chinese: String, _ english: String) -> ReaderError {
        var zh = "\(chinese)（Keychain \(status)）"
        var en = "\(english) (Keychain \(status))"
        if status == errSecMissingEntitlement {
            zh += "当前应用构建缺少钥匙串访问权限，请重新签名并安装应用。"
            en += " This app build lacks Keychain access entitlements. Rebuild with signing and reinstall."
        } else if status == errSecInteractionNotAllowed {
            zh += "请解锁设备后重试。"
            en += " Unlock the device and try again."
        }
        return ReaderError(zh, en)
    }
}

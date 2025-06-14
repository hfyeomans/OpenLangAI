import Foundation
import Security

public enum SyncPolicy { case local, iCloud }

public struct KeychainHelper {
    public static func save(_ key: String, sync: SyncPolicy) throws {
        let data = Data(key.utf8)
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "OpenAI_API_Key",
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        query[kSecAttrSynchronizable] = (sync == .iCloud) ? kCFBooleanTrue : kCFBooleanFalse

        SecItemDelete(query as CFDictionary) // remove old if exists
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }

    public static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "OpenAI_API_Key",
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    public static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "OpenAI_API_Key"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

import Foundation
import Security

public enum SyncPolicy { case local, iCloud }

public struct KeychainHelper {
    // MARK: - Provider-Specific API Key Management
    
    /// Generate keychain identifier for a specific provider
    public static func keychainKey(for provider: String) -> String {
        return "APIKey_\(provider)"
    }
    
    /// Save API key for a specific provider
    public static func save(_ key: String, provider: String, sync: SyncPolicy) throws {
        guard !key.isEmpty else {
            throw NSError(domain: "Keychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "API key cannot be empty"])
        }
        
        let data = Data(key.utf8)
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey(for: provider),
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]
        query[kSecAttrSynchronizable] = (sync == .iCloud) ? kCFBooleanTrue : kCFBooleanFalse
        
        SecItemDelete(query as CFDictionary) // remove old if exists
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw NSError(domain: "Keychain", code: Int(status)) }
    }
    
    /// Load API key for a specific provider
    public static func load(provider: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey(for: provider),
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
    
    /// Delete API key for a specific provider
    public static func delete(provider: String) throws {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: keychainKey(for: provider)
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NSError(domain: "Keychain", code: Int(status))
        }
    }
    
    /// Check if a key exists for a provider
    public static func hasKey(for provider: String) -> Bool {
        return load(provider: provider) != nil
    }
    
    /// Migrate legacy keys to provider-specific format
    public static func migrateLegacyKeysIfNeeded() {
        // Check if legacy OpenAI key exists
        if let legacyKey = load(), !hasKey(for: "ChatGPT") {
            // Migrate to new format
            try? save(legacyKey, provider: "ChatGPT", sync: .local)
        }
    }
    
    // MARK: - Legacy Methods (Backward Compatibility)
    
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
        // First try to load from legacy location
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "OpenAI_API_Key",
            kSecReturnData: kCFBooleanTrue!,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecSuccess, let data = item as? Data {
            return String(decoding: data, as: UTF8.self)
        }
        
        // If not found, try loading from new provider-specific location
        return load(provider: "ChatGPT")
    }

    public static func delete() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: "OpenAI_API_Key"
        ]
        SecItemDelete(query as CFDictionary)
    }
}

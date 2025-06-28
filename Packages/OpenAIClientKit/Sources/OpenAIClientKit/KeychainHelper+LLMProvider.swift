import Foundation
import SecureStoreKit

// Extension to KeychainHelper for LLM Provider-specific functionality
extension KeychainHelper {
    private static let providerKey = "selected_llm_provider"
    
    public static func saveSelectedProvider(_ provider: LLMProvider) {
        UserDefaults.standard.set(provider.rawValue, forKey: providerKey)
    }
    
    public static func loadSelectedProvider() -> LLMProvider {
        guard let providerString = UserDefaults.standard.string(forKey: providerKey),
              let provider = LLMProvider(rawValue: providerString) else {
            return .chatGPT // Default provider
        }
        return provider
    }
    
    // Provider-specific API key management
    public static func saveAPIKey(_ key: String, for provider: LLMProvider) {
        let keychainKey = "api_key_\(provider.rawValue.lowercased())"
        save(key, withKey: keychainKey)
    }
    
    public static func loadAPIKey(for provider: LLMProvider) -> String {
        let keychainKey = "api_key_\(provider.rawValue.lowercased())"
        return load(withKey: keychainKey)
    }
    
    // Helper to save with a specific key
    private static func save(_ value: String, withKey key: String) {
        if let data = value.data(using: .utf8) {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrAccount as String: key,
                kSecValueData as String: data
            ]
            
            SecItemDelete(query as CFDictionary)
            SecItemAdd(query as CFDictionary, nil)
        }
    }
    
    // Helper to load with a specific key
    private static func load(withKey key: String) -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess,
           let data = dataTypeRef as? Data,
           let value = String(data: data, encoding: .utf8) {
            return value
        }
        
        return ""
    }
}
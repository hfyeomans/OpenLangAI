import Foundation
import SecureStoreKit

// Extension to provide LLMProvider-based convenience methods
public extension KeychainHelper {
    
    /// Save API key for a specific LLM provider
    static func save(_ key: String, provider: LLMProvider, sync: SyncPolicy) throws {
        try save(key, provider: provider.rawValue, sync: sync)
    }
    
    /// Load API key for a specific LLM provider
    static func load(provider: LLMProvider) -> String? {
        return load(provider: provider.rawValue)
    }
    
    /// Delete API key for a specific LLM provider
    static func delete(provider: LLMProvider) throws {
        try delete(provider: provider.rawValue)
    }
    
    /// Check if a key exists for an LLM provider
    static func hasKey(for provider: LLMProvider) -> Bool {
        return hasKey(for: provider.rawValue)
    }
    
    /// Generate keychain identifier for an LLM provider
    static func keychainKey(for provider: LLMProvider) -> String {
        return keychainKey(for: provider.rawValue)
    }
}
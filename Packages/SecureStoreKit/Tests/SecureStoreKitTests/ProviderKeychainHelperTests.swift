import XCTest
@testable import SecureStoreKit

class ProviderKeychainHelperTests: XCTestCase {
    
    // Define test providers as strings
    let chatGPT = "ChatGPT"
    let claude = "Claude"
    let gemini = "Gemini"
    let testProviders = ["ChatGPT", "Claude", "Gemini"]
    
    override func setUp() {
        super.setUp()
        // Clear all provider keys before each test
        for provider in testProviders {
            try? KeychainHelper.delete(provider: provider)
        }
        // Also clear legacy key
        try? KeychainHelper.delete()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up after tests
        for provider in testProviders {
            try? KeychainHelper.delete(provider: provider)
        }
        try? KeychainHelper.delete()
    }
    
    // MARK: - Provider-Specific Save/Load Tests
    
    func testSaveAndLoadProviderSpecificKey() throws {
        // Given
        let openAIKey = "sk-openai-test-key-123"
        let claudeKey = "sk-claude-test-key-456"
        let geminiKey = "sk-gemini-test-key-789"
        
        // When
        try KeychainHelper.save(openAIKey, provider: chatGPT, sync: .local)
        try KeychainHelper.save(claudeKey, provider: claude, sync: .local)
        try KeychainHelper.save(geminiKey, provider: gemini, sync: .local)
        
        // Then
        XCTAssertEqual(KeychainHelper.load(provider: chatGPT), openAIKey)
        XCTAssertEqual(KeychainHelper.load(provider: claude), claudeKey)
        XCTAssertEqual(KeychainHelper.load(provider: gemini), geminiKey)
    }
    
    func testEachProviderHasSeparateKey() throws {
        // Given
        let testKey = "same-key-different-providers"
        
        // When - Save same key for different providers
        try KeychainHelper.save(testKey + "-openai", provider: chatGPT, sync: .local)
        try KeychainHelper.save(testKey + "-claude", provider: claude, sync: .local)
        
        // Then - Each provider should have its own key
        XCTAssertEqual(KeychainHelper.load(provider: chatGPT), testKey + "-openai")
        XCTAssertEqual(KeychainHelper.load(provider: claude), testKey + "-claude")
        XCTAssertNotEqual(KeychainHelper.load(provider: chatGPT), KeychainHelper.load(provider: claude))
    }
    
    func testLoadReturnsNilForUnsavedProvider() {
        // Given - No keys saved
        
        // When/Then
        XCTAssertNil(KeychainHelper.load(provider: chatGPT))
        XCTAssertNil(KeychainHelper.load(provider: claude))
        XCTAssertNil(KeychainHelper.load(provider: gemini))
    }
    
    // MARK: - Provider-Specific Delete Tests
    
    func testDeleteProviderSpecificKey() throws {
        // Given
        let key = "test-key-to-delete"
        try KeychainHelper.save(key, provider: chatGPT, sync: .local)
        
        // When
        try KeychainHelper.delete(provider: chatGPT)
        
        // Then
        XCTAssertNil(KeychainHelper.load(provider: chatGPT))
    }
    
    func testDeleteOnlyAffectsSpecificProvider() throws {
        // Given
        try KeychainHelper.save("key1", provider: chatGPT, sync: .local)
        try KeychainHelper.save("key2", provider: claude, sync: .local)
        try KeychainHelper.save("key3", provider: gemini, sync: .local)
        
        // When - Delete only Claude key
        try KeychainHelper.delete(provider: claude)
        
        // Then - Other keys remain
        XCTAssertNotNil(KeychainHelper.load(provider: chatGPT))
        XCTAssertNil(KeychainHelper.load(provider: claude))
        XCTAssertNotNil(KeychainHelper.load(provider: gemini))
    }
    
    // MARK: - Migration Tests
    
    func testMigrateLegacyOpenAIKey() throws {
        // Given - Legacy key exists
        let legacyKey = "sk-legacy-openai-key"
        try KeychainHelper.save(legacyKey, sync: .local)
        
        // When - Perform migration
        KeychainHelper.migrateLegacyKeysIfNeeded()
        
        // Then - Key should be available via provider-specific method
        XCTAssertEqual(KeychainHelper.load(provider: chatGPT), legacyKey)
        // Legacy method should still work for backward compatibility
        XCTAssertEqual(KeychainHelper.load(), legacyKey)
    }
    
    func testMigrationDoesNotOverwriteExistingProviderKey() throws {
        // Given
        let legacyKey = "sk-legacy-key"
        let newKey = "sk-new-provider-key"
        try KeychainHelper.save(legacyKey, sync: .local)
        try KeychainHelper.save(newKey, provider: chatGPT, sync: .local)
        
        // When
        KeychainHelper.migrateLegacyKeysIfNeeded()
        
        // Then - Existing provider key is preserved
        XCTAssertEqual(KeychainHelper.load(provider: chatGPT), newKey)
    }
    
    // MARK: - Key Validation Tests
    
    func testHasKeyForProvider() throws {
        // Given
        try KeychainHelper.save("test-key", provider: chatGPT, sync: .local)
        
        // When/Then
        XCTAssertTrue(KeychainHelper.hasKey(for: chatGPT))
        XCTAssertFalse(KeychainHelper.hasKey(for: claude))
        XCTAssertFalse(KeychainHelper.hasKey(for: gemini))
    }
    
    // MARK: - Error Handling Tests
    
    func testSaveEmptyKeyThrowsError() {
        // Given
        let emptyKey = ""
        
        // When/Then
        XCTAssertThrowsError(try KeychainHelper.save(emptyKey, provider: chatGPT, sync: .local))
    }
    
    // MARK: - Sync Policy Tests
    
    func testCloudSyncPolicyForProvider() throws {
        // Given
        let key = "cloud-sync-test-key"
        
        // When
        try KeychainHelper.save(key, provider: claude, sync: .cloud)
        
        // Then
        XCTAssertEqual(KeychainHelper.load(provider: claude), key)
    }
    
    // MARK: - Provider Identifier Tests
    
    func testProviderIdentifierFormat() {
        // Test that provider identifiers are correctly formatted
        XCTAssertEqual(KeychainHelper.keychainKey(for: chatGPT), "APIKey_ChatGPT")
        XCTAssertEqual(KeychainHelper.keychainKey(for: claude), "APIKey_Claude")
        XCTAssertEqual(KeychainHelper.keychainKey(for: gemini), "APIKey_Gemini")
    }
}
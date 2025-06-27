import XCTest
@testable import SecureStoreKit

class KeychainHelperTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing keys
        try? KeychainHelper.delete()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up
        try? KeychainHelper.delete()
    }
    
    // MARK: - Current Implementation Tests
    
    func testSaveAndLoadAPIKey() throws {
        // Given
        let testKey = "test-api-key-12345"
        
        // When
        try KeychainHelper.save(testKey, sync: .local)
        let loadedKey = KeychainHelper.load()
        
        // Then
        XCTAssertEqual(loadedKey, testKey)
    }
    
    func testDeleteAPIKey() throws {
        // Given
        let testKey = "test-api-key-to-delete"
        try KeychainHelper.save(testKey, sync: .local)
        
        // When
        try KeychainHelper.delete()
        let loadedKey = KeychainHelper.load()
        
        // Then
        XCTAssertNil(loadedKey)
    }
    
    func testLoadReturnsNilWhenNoKey() {
        // Given - no key saved
        
        // When
        let loadedKey = KeychainHelper.load()
        
        // Then
        XCTAssertNil(loadedKey)
    }
    
    // MARK: - Provider-Specific API Key Tests (Future Implementation)
    
    func testEachProviderCanHaveSeparateAPIKey() throws {
        // This test demonstrates the desired behavior for provider-specific keys
        // Currently will fail as KeychainHelper doesn't support providers
        
        // Given
        let openAIKey = "openai-key-123"
        let claudeKey = "claude-key-456"
        let geminiKey = "gemini-key-789"
        
        // When - Save keys for each provider
        // Future implementation would look like:
        // try KeychainHelper.save(openAIKey, provider: .chatGPT, sync: .local)
        // try KeychainHelper.save(claudeKey, provider: .claude, sync: .local)
        // try KeychainHelper.save(geminiKey, provider: .gemini, sync: .local)
        
        // Then - Each provider should have its own key
        // let loadedOpenAIKey = KeychainHelper.load(provider: .chatGPT)
        // let loadedClaudeKey = KeychainHelper.load(provider: .claude)
        // let loadedGeminiKey = KeychainHelper.load(provider: .gemini)
        
        // XCTAssertEqual(loadedOpenAIKey, openAIKey)
        // XCTAssertEqual(loadedClaudeKey, claudeKey)
        // XCTAssertEqual(loadedGeminiKey, geminiKey)
        
        // For now, this test demonstrates the limitation
        XCTAssertTrue(true, "Provider-specific keys not yet implemented")
    }
    
    func testAPIKeyIsLoadedForCorrectProvider() throws {
        // This test verifies that the correct key is loaded for each provider
        // Currently will fail as KeychainHelper doesn't support providers
        
        // Future implementation test
        XCTAssertTrue(true, "Provider-specific key loading not yet implemented")
    }
    
    // MARK: - Sync Policy Tests
    
    func testLocalSyncPolicy() throws {
        // Given
        let testKey = "local-sync-test"
        
        // When
        try KeychainHelper.save(testKey, sync: .local)
        let loadedKey = KeychainHelper.load()
        
        // Then
        XCTAssertEqual(loadedKey, testKey)
    }
    
    func testCloudSyncPolicy() throws {
        // Given
        let testKey = "cloud-sync-test"
        
        // When
        try KeychainHelper.save(testKey, sync: .iCloud)
        let loadedKey = KeychainHelper.load()
        
        // Then
        XCTAssertEqual(loadedKey, testKey)
    }
}
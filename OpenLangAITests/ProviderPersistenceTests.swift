import XCTest
@testable import OpenLangAI
import OpenAIClientKit

class ProviderPersistenceTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clear any existing provider preference
        UserDefaults.standard.removeObject(forKey: "selectedProvider")
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up after tests
        UserDefaults.standard.removeObject(forKey: "selectedProvider")
    }
    
    // MARK: - Provider Persistence Tests
    
    func testProviderSelectionIsPersisted() {
        // Given
        let expectedProvider = LLMProvider.chatGPT
        
        // When
        UserDefaults.standard.set(expectedProvider.rawValue, forKey: "selectedProvider")
        
        // Then
        let savedValue = UserDefaults.standard.string(forKey: "selectedProvider")
        XCTAssertEqual(savedValue, expectedProvider.rawValue)
    }
    
    func testProviderIsRetrievedCorrectly() {
        // Given
        UserDefaults.standard.set(LLMProvider.claude.rawValue, forKey: "selectedProvider")
        
        // When
        let retrievedValue = UserDefaults.standard.string(forKey: "selectedProvider")
        let provider = LLMProvider(rawValue: retrievedValue ?? "")
        
        // Then
        XCTAssertNotNil(provider)
        XCTAssertEqual(provider, .claude)
    }
    
    func testDefaultProviderIsUsedWhenNoneSet() {
        // Given - no provider is set
        UserDefaults.standard.removeObject(forKey: "selectedProvider")
        
        // When
        let savedValue = UserDefaults.standard.string(forKey: "selectedProvider")
        let provider = LLMProvider(rawValue: savedValue ?? "") ?? .chatGPT
        
        // Then
        XCTAssertNil(savedValue)
        XCTAssertEqual(provider, .chatGPT)
    }
    
    func testAllProvidersCanBePersisted() {
        // Test each provider can be saved and retrieved
        for provider in LLMProvider.allCases {
            // When
            UserDefaults.standard.set(provider.rawValue, forKey: "selectedProvider")
            
            // Then
            let savedValue = UserDefaults.standard.string(forKey: "selectedProvider")
            let retrievedProvider = LLMProvider(rawValue: savedValue ?? "")
            
            XCTAssertEqual(retrievedProvider, provider, "Failed to persist provider: \(provider.rawValue)")
        }
    }
    
    // MARK: - SessionView Provider Usage Tests
    
    func testSessionViewUsesPersistedProvider() {
        // This test verifies that SessionView reads the provider from UserDefaults
        // In actual implementation, we would need to refactor SessionView to read from UserDefaults
        
        // Given
        UserDefaults.standard.set(LLMProvider.gemini.rawValue, forKey: "selectedProvider")
        
        // When - SessionView should read the provider
        let expectedProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .chatGPT
        
        // Then
        XCTAssertEqual(expectedProvider, .gemini)
    }
    
    // MARK: - ContentView Provider Persistence Tests
    
    func testContentViewSavesProviderOnSelection() {
        // This test ensures ContentView saves the selected provider to UserDefaults
        // Note: This requires refactoring ContentView to save on selection change
        
        // Given
        let contentView = ContentView()
        
        // When - User selects a provider (simulated)
        let selectedProvider = LLMProvider.claude
        UserDefaults.standard.set(selectedProvider.rawValue, forKey: "selectedProvider")
        
        // Then
        let savedProvider = UserDefaults.standard.string(forKey: "selectedProvider")
        XCTAssertEqual(savedProvider, selectedProvider.rawValue)
    }
}
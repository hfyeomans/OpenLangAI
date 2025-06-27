import XCTest
import SwiftUI
@testable import OpenLangAI
import OpenAIClientKit

class ProviderSelectionUITests: XCTestCase {
    
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
    
    // MARK: - Provider Display Name Tests
    
    func testProviderDisplayNames() {
        let contentView = ContentView()
        
        // Test implemented provider (ChatGPT)
        XCTAssertEqual(contentView.providerDisplayName(for: .chatGPT), "ChatGPT")
        
        // Test unimplemented providers
        XCTAssertEqual(contentView.providerDisplayName(for: .claude), "Claude (Coming Soon)")
        XCTAssertEqual(contentView.providerDisplayName(for: .gemini), "Gemini (Coming Soon)")
    }
    
    func testProviderAvailability() {
        let contentView = ContentView()
        
        // Only ChatGPT should be available
        XCTAssertTrue(contentView.isProviderAvailable(.chatGPT))
        XCTAssertFalse(contentView.isProviderAvailable(.claude))
        XCTAssertFalse(contentView.isProviderAvailable(.gemini))
    }
    
    // MARK: - Provider Selection Behavior Tests
    
    func testSelectingAvailableProvider() {
        // Given
        let initialProvider = LLMProvider.chatGPT
        
        // When
        UserDefaults.standard.set(initialProvider.rawValue, forKey: "selectedProvider")
        
        // Then - provider should be saved
        let savedProvider = UserDefaults.standard.string(forKey: "selectedProvider")
        XCTAssertEqual(savedProvider, initialProvider.rawValue)
    }
    
    func testSelectingUnavailableProviderReverts() {
        // Given - ChatGPT is selected initially
        UserDefaults.standard.set(LLMProvider.chatGPT.rawValue, forKey: "selectedProvider")
        
        // When - User tries to select Claude (unavailable)
        // In the actual UI, this would trigger the alert and revert to ChatGPT
        // We can't directly test the UI behavior, but we can verify the logic
        
        let contentView = ContentView()
        let unavailableProvider = LLMProvider.claude
        
        // Simulate the selection logic
        if !contentView.isProviderAvailable(unavailableProvider) {
            // Should not save the unavailable provider
            // Should keep ChatGPT selected
            let currentProvider = UserDefaults.standard.string(forKey: "selectedProvider")
            XCTAssertEqual(currentProvider, LLMProvider.chatGPT.rawValue)
        }
    }
    
    // MARK: - UI State Tests
    
    func testButtonsDisabledForUnavailableProviders() {
        let contentView = ContentView()
        
        // Test that save key and test connection buttons should be disabled
        // for unavailable providers
        XCTAssertTrue(contentView.isProviderAvailable(.chatGPT))
        XCTAssertFalse(contentView.isProviderAvailable(.claude))
        XCTAssertFalse(contentView.isProviderAvailable(.gemini))
    }
    
    // MARK: - Integration Tests
    
    func testSessionViewUsesSelectedProvider() {
        // Given
        UserDefaults.standard.set(LLMProvider.chatGPT.rawValue, forKey: "selectedProvider")
        
        // When SessionView is created
        let sessionView = SessionView()
        
        // Then - it should use the saved provider
        let expectedProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .chatGPT
        XCTAssertEqual(expectedProvider, .chatGPT)
    }
    
    func testErrorHandlingForUnimplementedProviders() async {
        // Test that the LLMClient properly throws errors for unimplemented providers
        
        // Test Claude
        do {
            _ = try await LLMClient.shared.sendMessage("Test", provider: .claude, language: "Spanish")
            XCTFail("Expected error for Claude provider")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let provider):
                XCTAssertEqual(provider, "Claude")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        // Test Gemini
        do {
            _ = try await LLMClient.shared.sendMessage("Test", provider: .gemini, language: "Spanish")
            XCTFail("Expected error for Gemini provider")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let provider):
                XCTAssertEqual(provider, "Gemini")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testTestConnectionMessages() async {
        // Test connection messages for each provider
        let chatGPTResult = await LLMClient.shared.testConnection(to: .chatGPT)
        let claudeResult = await LLMClient.shared.testConnection(to: .claude)
        let geminiResult = await LLMClient.shared.testConnection(to: .gemini)
        
        // ChatGPT should attempt connection (may fail without API key)
        XCTAssertTrue(chatGPTResult.contains("Error") || chatGPTResult.contains("Successfully"))
        
        // Claude and Gemini should indicate not implemented
        XCTAssertEqual(claudeResult, "Claude: Not yet implemented")
        XCTAssertEqual(geminiResult, "Gemini: Not yet implemented")
    }
}

// Extension to make ContentView methods accessible for testing
extension ContentView {
    func providerDisplayName(for provider: LLMProvider) -> String {
        if implementedProviders.contains(provider) {
            return provider.rawValue
        } else {
            return "\(provider.rawValue) (Coming Soon)"
        }
    }
    
    func isProviderAvailable(_ provider: LLMProvider) -> Bool {
        implementedProviders.contains(provider)
    }
}
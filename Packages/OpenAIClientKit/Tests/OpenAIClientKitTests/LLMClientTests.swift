import XCTest
@testable import OpenAIClientKit
import SecureStoreKit

class LLMClientTests: XCTestCase {
    
    var sut: LLMClient!
    
    override func setUp() {
        super.setUp()
        sut = LLMClient.shared
        // Clear any existing API keys
        try? KeychainHelper.delete()
    }
    
    override func tearDown() {
        super.tearDown()
        // Clean up
        try? KeychainHelper.delete()
    }
    
    // MARK: - Provider Not Implemented Tests
    
    func testClaudeProviderThrowsNotImplementedError() async {
        // Given
        let provider = LLMProvider.claude
        
        // When/Then
        do {
            _ = try await sut.sendMessage("Hello", provider: provider, language: "Spanish")
            XCTFail("Expected providerNotImplemented error")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let providerName):
                XCTAssertEqual(providerName, "Claude")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testGeminiProviderThrowsNotImplementedError() async {
        // Given
        let provider = LLMProvider.gemini
        
        // When/Then
        do {
            _ = try await sut.sendMessage("Hello", provider: provider, language: "French")
            XCTFail("Expected providerNotImplemented error")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let providerName):
                XCTAssertEqual(providerName, "Gemini")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - API Key Validation Tests
    
    func testValidateAPIKeyThrowsForClaudeProvider() async {
        // Given
        let provider = LLMProvider.claude
        
        // When/Then
        do {
            _ = try await sut.validateAPIKey(for: provider)
            XCTFail("Expected providerNotImplemented error")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let providerName):
                XCTAssertEqual(providerName, "Claude")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testValidateAPIKeyThrowsForGeminiProvider() async {
        // Given
        let provider = LLMProvider.gemini
        
        // When/Then
        do {
            _ = try await sut.validateAPIKey(for: provider)
            XCTFail("Expected providerNotImplemented error")
        } catch let error as LLMError {
            switch error {
            case .providerNotImplemented(let providerName):
                XCTAssertEqual(providerName, "Gemini")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Test Connection Tests
    
    func testConnectionReturnsNotImplementedForClaude() async {
        // Given
        let provider = LLMProvider.claude
        
        // When
        let result = await sut.testConnection(to: provider)
        
        // Then
        XCTAssertEqual(result, "Claude: Not yet implemented")
    }
    
    func testConnectionReturnsNotImplementedForGemini() async {
        // Given
        let provider = LLMProvider.gemini
        
        // When
        let result = await sut.testConnection(to: provider)
        
        // Then
        XCTAssertEqual(result, "Gemini: Not yet implemented")
    }
    
    // MARK: - Error Description Tests
    
    func testLLMErrorProviderNotImplementedDescription() {
        // Given
        let error = LLMError.providerNotImplemented("TestProvider")
        
        // When
        let description = error.errorDescription
        
        // Then
        XCTAssertEqual(description, "TestProvider provider is not yet implemented.")
    }
}
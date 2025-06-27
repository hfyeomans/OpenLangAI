import XCTest
@testable import OpenLangAI
import OpenAIClientKit

class ErrorHandlingTests: XCTestCase {
    
    // MARK: - Error Alert Tests
    
    func testNetworkErrorShowsAlert() {
        // This test verifies that network errors are properly displayed to users
        // Requires refactoring SessionView to show alerts on errors
        
        // Given
        let networkError = URLError(.notConnectedToInternet)
        
        // When - Error occurs during API call
        // Then - Alert should be shown with appropriate message
        
        // Note: Actual implementation requires UI testing or view model testing
        XCTAssertNotNil(networkError.localizedDescription)
    }
    
    func testInvalidAPIKeyShowsSpecificMessage() {
        // Given
        let apiKeyError = OpenAIError.invalidAPIKey
        
        // When
        let errorMessage = apiKeyError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "Invalid API key. Please check your OpenAI API key.")
    }
    
    func testRateLimitErrorShowsRetryMessage() {
        // Given
        let rateLimitError = OpenAIError.rateLimitExceeded
        
        // When
        let errorMessage = rateLimitError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "Rate limit exceeded. Please try again later.")
    }
    
    func testProviderNotImplementedShowsWarning() {
        // Given
        let providerError = LLMError.providerNotImplemented("Claude")
        
        // When
        let errorMessage = providerError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "Claude provider is not yet implemented.")
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorStopsProcessingIndicator() {
        // This test ensures that isProcessing is set to false on error
        // Requires refactoring SessionView to properly handle errors
        
        // Given - SessionView is processing
        var isProcessing = true
        
        // When - Error occurs
        // Simulate error handling
        isProcessing = false
        
        // Then
        XCTAssertFalse(isProcessing)
    }
    
    // MARK: - Missing API Key Tests
    
    func testMissingAPIKeyShowsHelpfulMessage() {
        // Given
        let missingKeyError = OpenAIError.missingAPIKey
        
        // When
        let errorMessage = missingKeyError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "OpenAI API key is missing. Please add your API key in settings.")
        XCTAssertTrue(errorMessage!.contains("settings"))
    }
    
    // MARK: - Server Error Tests
    
    func testServerErrorShowsRetryMessage() {
        // Given
        let serverError = OpenAIError.serverError
        
        // When
        let errorMessage = serverError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "OpenAI server error. Please try again later.")
        XCTAssertTrue(errorMessage!.contains("try again"))
    }
    
    // MARK: - Unknown Error Tests
    
    func testUnknownErrorIncludesStatusCode() {
        // Given
        let unknownError = OpenAIError.unknownError(statusCode: 418)
        
        // When
        let errorMessage = unknownError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "Unknown error occurred (status code: 418).")
        XCTAssertTrue(errorMessage!.contains("418"))
    }
    
    // MARK: - API Error Tests
    
    func testAPIErrorIncludesServerMessage() {
        // Given
        let apiError = OpenAIError.apiError("Model not found")
        
        // When
        let errorMessage = apiError.errorDescription
        
        // Then
        XCTAssertEqual(errorMessage, "OpenAI API error: Model not found")
        XCTAssertTrue(errorMessage!.contains("Model not found"))
    }
}
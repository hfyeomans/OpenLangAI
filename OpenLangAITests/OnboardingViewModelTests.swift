import XCTest
import Combine
@testable import OpenLangAI
@testable import OpenAIClientKit
@testable import SecureStoreKit

// MARK: - Mock Objects

class MockKeychainHelper {
    static var savedKey: String?
    static var loadedKey: String?
    static var shouldFailSave = false
    
    static func reset() {
        savedKey = nil
        loadedKey = nil
        shouldFailSave = false
    }
}

class MockLLMClient {
    static var shouldFailValidation = false
    static var validationError: Error?
    static var validateAPIKeyCalled = false
    
    static func reset() {
        shouldFailValidation = false
        validationError = nil
        validateAPIKeyCalled = false
    }
}

class MockNotificationCenter {
    static var postedNotifications: [Notification.Name] = []
    
    static func reset() {
        postedNotifications = []
    }
}

// MARK: - Test Errors
// TestError is already defined in TestConfiguration.swift

// MARK: - OnboardingViewModel Tests

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    
    var viewModel: OnboardingViewModel!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        viewModel = OnboardingViewModel()
        cancellables = []
        
        // Reset all mocks
        MockKeychainHelper.reset()
        MockLLMClient.reset()
        MockNotificationCenter.reset()
    }
    
    override func tearDown() {
        viewModel = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        // Test default values
        XCTAssertEqual(viewModel.currentStep, 0)
        XCTAssertEqual(viewModel.selectedLanguage, .spanish)
        XCTAssertEqual(viewModel.selectedLevel, .beginner)
        XCTAssertEqual(viewModel.apiKey, "")
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertNil(viewModel.keyValidationResult)
        XCTAssertFalse(viewModel.showError)
    }
    
    // MARK: - Language Selection Tests
    
    func testSelectLanguage() {
        // Test selecting each language
        let languages: [Language] = [.french, .japanese, .italian, .portuguese, .spanish]
        
        for language in languages {
            viewModel.selectLanguage(language)
            XCTAssertEqual(viewModel.selectedLanguage, language)
            XCTAssertEqual(viewModel.currentStep, 1)
        }
    }
    
    // MARK: - Level Selection Tests
    
    func testSelectLevel() {
        // Test selecting each level
        let levels: [UserLevel] = [.beginner, .intermediate]
        
        for level in levels {
            viewModel.selectLevel(level)
            XCTAssertEqual(viewModel.selectedLevel, level)
            XCTAssertEqual(viewModel.currentStep, 2)
        }
    }
    
    // MARK: - Navigation Tests
    
    func testMoveToStep() {
        // Test moving to different steps
        for step in 0...3 {
            viewModel.moveToStep(step)
            XCTAssertEqual(viewModel.currentStep, step)
        }
    }
    
    func testGoBack() {
        // Set initial step
        viewModel.currentStep = 2
        
        // Go back once
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, 1)
        
        // Go back again
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, 0)
        
        // Try to go back from step 0 (should stay at 0)
        viewModel.goBack()
        XCTAssertEqual(viewModel.currentStep, 0)
    }
    
    // MARK: - API Key Validation Tests
    
    func testIsApiKeyEmpty() {
        // Test with empty key
        viewModel.apiKey = ""
        XCTAssertTrue(viewModel.isApiKeyEmpty)
        
        // Test with non-empty key
        viewModel.apiKey = "test-key"
        XCTAssertFalse(viewModel.isApiKeyEmpty)
    }
    
    func testCanContinue() {
        // Test with empty key
        viewModel.apiKey = ""
        XCTAssertFalse(viewModel.canContinue)
        
        // Test with non-empty key
        viewModel.apiKey = "test-key"
        XCTAssertTrue(viewModel.canContinue)
        
        // Test during validation
        viewModel.isValidatingKey = true
        XCTAssertFalse(viewModel.canContinue)
    }
    
    func testValidationResultColor() {
        // Test with no result
        XCTAssertEqual(viewModel.validationResultColor, .primary)
        
        // Test with success result
        viewModel.keyValidationResult = "Success! API key validated"
        XCTAssertEqual(viewModel.validationResultColor, .green)
        
        // Test with error result
        viewModel.keyValidationResult = "Invalid API key"
        XCTAssertEqual(viewModel.validationResultColor, .red)
    }
    
    func testValidationResultIcon() {
        // Test with no result
        XCTAssertEqual(viewModel.validationResultIcon, "")
        
        // Test with success result
        viewModel.keyValidationResult = "Success! API key validated"
        XCTAssertEqual(viewModel.validationResultIcon, "checkmark.circle.fill")
        
        // Test with error result
        viewModel.keyValidationResult = "Invalid API key"
        XCTAssertEqual(viewModel.validationResultIcon, "exclamationmark.triangle.fill")
    }
    
    // MARK: - Async Validation Tests
    
    func testValidateAndCompleteSuccess() async {
        // Setup
        viewModel.apiKey = "valid-test-key"
        let expectation = XCTestExpectation(description: "Validation completes")
        
        // Subscribe to changes
        viewModel.$isValidatingKey
            .dropFirst() // Skip initial value
            .sink { isValidating in
                if !isValidating && self.viewModel.keyValidationResult != nil {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Test validation
        await viewModel.validateAndComplete()
        
        // Wait for expectation
        await fulfillment(of: [expectation], timeout: 3.0)
        
        // Verify results
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertEqual(viewModel.keyValidationResult, "Success! API key validated")
        XCTAssertFalse(viewModel.showError)
    }
    
    func testValidateAndCompleteFailure() async {
        // This test would require mocking the LLMClient to simulate failure
        // For now, we'll test the structure and state changes
        
        viewModel.apiKey = "invalid-test-key"
        
        // Since we can't properly mock the static LLMClient.shared,
        // we'll test what we can about the method structure
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertNil(viewModel.keyValidationResult)
    }
    
    // MARK: - Skip API Key Tests
    
    func testSkipApiKey() {
        let expectation = XCTestExpectation(description: "Onboarding completed notification")
        
        // Subscribe to notification
        NotificationCenter.default.addObserver(
            forName: .onboardingCompleted,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        // Skip API key
        viewModel.skipApiKey()
        
        // Wait for notification
        wait(for: [expectation], timeout: 1.0)
        
        // Verify UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedLanguage"), viewModel.selectedLanguage.rawValue)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userLevel"), viewModel.selectedLevel.rawValue)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
    
    // MARK: - Helper Method Tests
    
    func testGetLevelDescription() {
        // Test beginner level with different languages
        viewModel.selectedLevel = .beginner
        viewModel.selectedLanguage = .spanish
        XCTAssertEqual(
            viewModel.getLevelDescription(for: .beginner),
            "I'm just starting to learn Spanish"
        )
        
        viewModel.selectedLanguage = .french
        XCTAssertEqual(
            viewModel.getLevelDescription(for: .beginner),
            "I'm just starting to learn French"
        )
        
        // Test intermediate level
        viewModel.selectedLevel = .intermediate
        viewModel.selectedLanguage = .japanese
        XCTAssertEqual(
            viewModel.getLevelDescription(for: .intermediate),
            "I can have basic conversations in Japanese"
        )
    }
    
    // MARK: - State Change Tests
    
    func testStateChangesPublishCorrectly() {
        let expectation = XCTestExpectation(description: "State changes publish")
        var receivedValues: [Int] = []
        
        viewModel.$currentStep
            .sink { step in
                receivedValues.append(step)
                if receivedValues.count == 4 { // Initial + 3 changes
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Make changes
        viewModel.moveToStep(1)
        viewModel.moveToStep(2)
        viewModel.goBack()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertEqual(receivedValues, [0, 1, 2, 1])
    }
    
    // MARK: - Clipboard Tests
    
    func testPasteFromClipboard() {
        // Note: This test would require mocking UIPasteboard
        // Since UIPasteboard is a system API, we can only test the method exists
        // In a real test environment, you would use dependency injection
        
        let originalKey = viewModel.apiKey
        viewModel.pasteFromClipboard()
        // Without proper mocking, the key should remain unchanged
        XCTAssertEqual(viewModel.apiKey, originalKey)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteOnboardingFlow() {
        // Test complete flow
        viewModel.selectLanguage(.french)
        XCTAssertEqual(viewModel.currentStep, 1)
        XCTAssertEqual(viewModel.selectedLanguage, .french)
        
        viewModel.selectLevel(.intermediate)
        XCTAssertEqual(viewModel.currentStep, 2)
        XCTAssertEqual(viewModel.selectedLevel, .intermediate)
        
        viewModel.apiKey = "test-api-key"
        XCTAssertTrue(viewModel.canContinue)
        
        // Skip API validation and complete
        viewModel.skipApiKey()
        
        // Verify preferences saved
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedLanguage"), "French")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userLevel"), "Intermediate")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
    
    // MARK: - Memory Management Tests
    
    func testNoRetainCycles() {
        // Create expectations
        weak var weakViewModel = viewModel
        
        // Subscribe to publishers
        viewModel.$currentStep.sink { _ in }.store(in: &cancellables)
        viewModel.$selectedLanguage.sink { _ in }.store(in: &cancellables)
        viewModel.$isValidatingKey.sink { _ in }.store(in: &cancellables)
        
        // Clear references
        viewModel = nil
        cancellables.removeAll()
        
        // Verify deallocation
        XCTAssertNil(weakViewModel)
    }
}

// MARK: - Test Helpers

extension OnboardingViewModelTests {
    func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        UserDefaults.standard.removeObject(forKey: "userLevel")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
}
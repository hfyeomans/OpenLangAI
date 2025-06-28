import XCTest
import Combine
import SwiftUI
@testable import OpenLangAI
@testable import OpenAIClientKit
@testable import SecureStoreKit

// MARK: - OnboardingViewModel Tests with Dependency Injection

@MainActor
final class OnboardingViewModelDITests: XCTestCase {
    
    var viewModel: TestableOnboardingViewModel!
    var mockKeychain: MockKeychainHelperDI.Type!
    var mockLLMClient: MockLLMClientDI!
    var mockPasteboard: MockPasteboard!
    var notificationObserver: TestNotificationObserver!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        
        // Setup mocks
        mockKeychain = MockKeychainHelperDI.self
        mockKeychain.reset()
        
        mockLLMClient = MockLLMClientDI()
        mockPasteboard = MockPasteboard()
        notificationObserver = TestNotificationObserver()
        cancellables = []
        
        // Clear UserDefaults
        clearUserDefaults()
        
        // Create view model with mocks
        viewModel = TestableOnboardingViewModel(
            keychainHelper: mockKeychain,
            llmClient: mockLLMClient,
            pasteboard: mockPasteboard
        )
    }
    
    override func tearDown() {
        viewModel = nil
        mockKeychain = nil
        mockLLMClient = nil
        mockPasteboard = nil
        notificationObserver = nil
        cancellables = nil
        clearUserDefaults()
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithExistingAPIKey() {
        // Setup
        mockKeychain.loadReturnValue = "existing-api-key"
        
        // Create new view model
        let vm = TestableOnboardingViewModel(
            keychainHelper: mockKeychain,
            llmClient: mockLLMClient,
            pasteboard: mockPasteboard
        )
        
        // Verify
        XCTAssertEqual(vm.apiKey, "existing-api-key")
    }
    
    func testInitializationWithoutExistingAPIKey() {
        // Setup
        mockKeychain.loadReturnValue = nil
        
        // Create new view model
        let vm = TestableOnboardingViewModel(
            keychainHelper: mockKeychain,
            llmClient: mockLLMClient,
            pasteboard: mockPasteboard
        )
        
        // Verify
        XCTAssertEqual(vm.apiKey, "")
    }
    
    // MARK: - Clipboard Tests
    
    func testPasteFromClipboardWithContent() {
        // Setup
        mockPasteboard.string = "pasted-api-key"
        
        // Action
        viewModel.pasteFromClipboard()
        
        // Verify
        XCTAssertEqual(viewModel.apiKey, "pasted-api-key")
    }
    
    func testPasteFromClipboardEmpty() {
        // Setup
        mockPasteboard.string = nil
        viewModel.apiKey = "original-key"
        
        // Action
        viewModel.pasteFromClipboard()
        
        // Verify
        XCTAssertEqual(viewModel.apiKey, "original-key")
    }
    
    // MARK: - API Key Validation Tests
    
    func testValidateAndCompleteSuccess() async {
        // Setup
        viewModel.apiKey = "valid-test-key"
        mockLLMClient.shouldThrowError = false
        notificationObserver.observe(name: .onboardingCompleted)
        
        // Action
        await viewModel.validateAndComplete()
        
        // Verify
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertEqual(viewModel.keyValidationResult, "Success! API key validated")
        XCTAssertFalse(viewModel.showError)
        XCTAssertTrue(mockLLMClient.validateAPIKeyCalled)
        XCTAssertEqual(mockLLMClient.validateAPIKeyProvider, .chatGPT)
        XCTAssertEqual(mockKeychain.savedKeys.last, "valid-test-key")
        
        // Wait a bit for completion
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify notification was sent
        XCTAssertTrue(notificationObserver.receivedNotifications.contains { $0.name == .onboardingCompleted })
        
        // Verify UserDefaults
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
    
    func testValidateAndCompleteKeychainFailure() async {
        // Setup
        viewModel.apiKey = "test-key"
        mockKeychain.shouldThrowOnSave = true
        mockKeychain.saveError = NSError(domain: "Keychain", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to save to keychain"])
        
        // Action
        await viewModel.validateAndComplete()
        
        // Verify
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertEqual(viewModel.keyValidationResult, "Failed to save to keychain")
        XCTAssertTrue(viewModel.showError)
        XCTAssertFalse(mockLLMClient.validateAPIKeyCalled)
    }
    
    func testValidateAndCompleteLLMFailure() async {
        // Setup
        viewModel.apiKey = "invalid-test-key"
        mockLLMClient.shouldThrowError = true
        mockLLMClient.errorToThrow = NSError(domain: "OpenAI", code: 401, userInfo: [NSLocalizedDescriptionKey: "Invalid API key"])
        
        // Action
        await viewModel.validateAndComplete()
        
        // Verify
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertEqual(viewModel.keyValidationResult, "Invalid API key")
        XCTAssertTrue(viewModel.showError)
        XCTAssertTrue(mockLLMClient.validateAPIKeyCalled)
        XCTAssertEqual(mockKeychain.savedKeys.last, "invalid-test-key") // Key was saved before validation
    }
    
    func testValidationStateChanges() async {
        // Setup
        viewModel.apiKey = "test-key"
        var stateChanges: [(isValidating: Bool, result: String?)] = []
        
        // Subscribe to state changes
        Publishers.CombineLatest(
            viewModel.$isValidatingKey,
            viewModel.$keyValidationResult
        )
        .sink { isValidating, result in
            stateChanges.append((isValidating, result))
        }
        .store(in: &cancellables)
        
        // Action
        await viewModel.validateAndComplete()
        
        // Verify state transitions
        XCTAssertGreaterThanOrEqual(stateChanges.count, 3)
        
        // Initial state
        XCTAssertEqual(stateChanges[0].isValidating, false)
        XCTAssertNil(stateChanges[0].result)
        
        // During validation
        let validatingStates = stateChanges.filter { $0.isValidating }
        XCTAssertGreaterThan(validatingStates.count, 0)
        
        // Final state
        let lastState = stateChanges.last!
        XCTAssertFalse(lastState.isValidating)
        XCTAssertNotNil(lastState.result)
    }
    
    // MARK: - Skip API Key Tests
    
    func testSkipApiKeyCompletesOnboarding() {
        // Setup
        viewModel.selectedLanguage = .japanese
        viewModel.selectedLevel = .intermediate
        notificationObserver.observe(name: .onboardingCompleted)
        
        // Action
        viewModel.skipApiKey()
        
        // Verify notification
        XCTAssertEqual(notificationObserver.receivedNotifications.count, 1)
        XCTAssertEqual(notificationObserver.receivedNotifications[0].name, .onboardingCompleted)
        
        // Verify UserDefaults
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedLanguage"), "Japanese")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userLevel"), "Intermediate")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
    }
    
    // MARK: - Complete Flow Tests
    
    func testCompleteOnboardingFlowWithValidation() async {
        // Setup
        notificationObserver.observe(name: .onboardingCompleted)
        
        // Step 1: Select language
        viewModel.selectLanguage(.italian)
        XCTAssertEqual(viewModel.currentStep, 1)
        XCTAssertEqual(viewModel.selectedLanguage, .italian)
        
        // Step 2: Select level
        viewModel.selectLevel(.beginner)
        XCTAssertEqual(viewModel.currentStep, 2)
        XCTAssertEqual(viewModel.selectedLevel, .beginner)
        
        // Step 3: Enter API key
        viewModel.apiKey = "test-api-key-123"
        XCTAssertTrue(viewModel.canContinue)
        
        // Step 4: Validate and complete
        await viewModel.validateAndComplete()
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 2_000_000_000)
        
        // Verify final state
        XCTAssertEqual(viewModel.keyValidationResult, "Success! API key validated")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "selectedLanguage"), "Italian")
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userLevel"), "Complete Beginner")
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        // Setup
        viewModel.apiKey = "performance-test-key"
        mockLLMClient.validationDelay = 0.1 // 100ms delay
        
        measure {
            let expectation = XCTestExpectation(description: "Validation completes")
            
            Task { @MainActor in
                await viewModel.validateAndComplete()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 3.0)
        }
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentValidationAttempts() async {
        // Setup
        viewModel.apiKey = "concurrent-test-key"
        mockLLMClient.validationDelay = 0.5 // 500ms delay
        
        // Start multiple validation attempts
        async let validation1 = viewModel.validateAndComplete()
        async let validation2 = viewModel.validateAndComplete()
        
        // Wait for both to complete
        await validation1
        await validation2
        
        // Verify only one validation actually occurred (due to isValidatingKey flag)
        XCTAssertFalse(viewModel.isValidatingKey)
        XCTAssertNotNil(viewModel.keyValidationResult)
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyAPIKeyValidation() async {
        // Setup
        viewModel.apiKey = ""
        
        // Verify cannot continue
        XCTAssertFalse(viewModel.canContinue)
    }
    
    func testWhitespaceOnlyAPIKey() async {
        // Setup
        viewModel.apiKey = "   "
        
        // Note: The current implementation doesn't trim whitespace
        // This test documents the current behavior
        XCTAssertTrue(viewModel.canContinue) // Because it's not empty
    }
    
    func testVeryLongAPIKey() async {
        // Setup
        let longKey = String(repeating: "a", count: 1000)
        viewModel.apiKey = longKey
        
        // Action
        await viewModel.validateAndComplete()
        
        // Verify it was saved
        XCTAssertEqual(mockKeychain.savedKeys.last, longKey)
    }
    
    // MARK: - Helpers
    
    private func clearUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "selectedLanguage")
        UserDefaults.standard.removeObject(forKey: "userLevel")
        UserDefaults.standard.removeObject(forKey: "hasCompletedOnboarding")
    }
}
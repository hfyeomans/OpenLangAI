import Foundation
import Combine
import UIKit
import SwiftUI
@testable import OpenLangAI
@testable import OpenAIClientKit
@testable import SecureStoreKit

// MARK: - Protocol Definitions for Dependency Injection

protocol KeychainHelperProtocol {
    static func save(_ key: String, sync: SyncPolicy) throws
    static func load() -> String?
    static func delete()
}

protocol LLMClientProtocol {
    func validateAPIKey(for provider: LLMProvider) async throws -> Bool
}

protocol PasteboardProtocol {
    var string: String? { get }
}

// MARK: - Mock Implementations

class MockKeychainHelperDI: KeychainHelperProtocol {
    static var savedKeys: [String] = []
    static var loadReturnValue: String?
    static var shouldThrowOnSave = false
    static var saveError: Error = NSError(domain: "MockKeychain", code: 1, userInfo: nil)
    
    static func save(_ key: String, sync: SyncPolicy) throws {
        if shouldThrowOnSave {
            throw saveError
        }
        savedKeys.append(key)
    }
    
    static func load() -> String? {
        return loadReturnValue
    }
    
    static func delete() {
        savedKeys.removeAll()
        loadReturnValue = nil
    }
    
    static func reset() {
        savedKeys.removeAll()
        loadReturnValue = nil
        shouldThrowOnSave = false
    }
}

class MockLLMClientDI: LLMClientProtocol {
    var validateAPIKeyCalled = false
    var validateAPIKeyProvider: LLMProvider?
    var shouldThrowError = false
    var errorToThrow: Error = NSError(domain: "MockLLM", code: 1, userInfo: nil)
    var validationDelay: TimeInterval = 0
    
    func validateAPIKey(for provider: LLMProvider) async throws -> Bool {
        validateAPIKeyCalled = true
        validateAPIKeyProvider = provider
        
        if validationDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(validationDelay * 1_000_000_000))
        }
        
        if shouldThrowError {
            throw errorToThrow
        }
        
        return true
    }
    
    func reset() {
        validateAPIKeyCalled = false
        validateAPIKeyProvider = nil
        shouldThrowError = false
        validationDelay = 0
    }
}

class MockPasteboard: PasteboardProtocol {
    var string: String?
    
    init(string: String? = nil) {
        self.string = string
    }
}

// MARK: - Testable OnboardingViewModel

@MainActor
class TestableOnboardingViewModel: ObservableObject {
    // MARK: - Published Properties (same as original)
    
    @Published var currentStep = 0
    @Published var selectedLanguage: Language = .spanish
    @Published var selectedLevel: UserLevel = .beginner
    @Published var apiKey: String = ""
    @Published var isValidatingKey = false
    @Published var keyValidationResult: String?
    @Published var showError = false
    
    // MARK: - Dependencies
    
    private let keychainHelper: KeychainHelperProtocol.Type
    private let llmClient: LLMClientProtocol
    private let pasteboard: PasteboardProtocol
    private let notificationCenter: NotificationCenter
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        keychainHelper: KeychainHelperProtocol.Type,
        llmClient: LLMClientProtocol,
        pasteboard: PasteboardProtocol,
        notificationCenter: NotificationCenter = .default
    ) {
        self.keychainHelper = keychainHelper
        self.llmClient = llmClient
        self.pasteboard = pasteboard
        self.notificationCenter = notificationCenter
        
        // Load existing API key from Keychain if available
        self.apiKey = keychainHelper.load() ?? ""
    }
    
    // MARK: - Navigation Methods (same as original)
    
    func selectLanguage(_ language: Language) {
        selectedLanguage = language
        moveToStep(1)
    }
    
    func selectLevel(_ level: UserLevel) {
        selectedLevel = level
        moveToStep(2)
    }
    
    func moveToStep(_ step: Int) {
        // Note: withAnimation cannot be used in non-UI context
        currentStep = step
    }
    
    func goBack() {
        // Note: withAnimation cannot be used in non-UI context
        if currentStep > 0 {
            currentStep -= 1
        }
    }
    
    // MARK: - API Key Handling
    
    func pasteFromClipboard() {
        if let pasteboardString = pasteboard.string {
            apiKey = pasteboardString
        }
    }
    
    func validateAndComplete() async {
        isValidatingKey = true
        keyValidationResult = nil
        
        do {
            // Save the key first
            try keychainHelper.save(apiKey, sync: SyncPolicy.local)
            
            // Validate with OpenAI
            _ = try await llmClient.validateAPIKey(for: .chatGPT)
            
            keyValidationResult = "Success! API key validated"
            isValidatingKey = false
            
            // Complete onboarding after a short delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            completeOnboarding()
            
        } catch {
            keyValidationResult = error.localizedDescription
            isValidatingKey = false
            showError = true
        }
    }
    
    func skipApiKey() {
        completeOnboarding()
    }
    
    // MARK: - Onboarding Completion
    
    private func completeOnboarding() {
        // Save preferences to UserDefaults
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
        UserDefaults.standard.set(selectedLevel.rawValue, forKey: "userLevel")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Notify the view that onboarding is complete
        notificationCenter.post(name: .onboardingCompleted, object: nil)
    }
    
    // MARK: - Validation Methods (same as original)
    
    var isApiKeyEmpty: Bool {
        apiKey.isEmpty
    }
    
    var canContinue: Bool {
        !isApiKeyEmpty && !isValidatingKey
    }
    
    var validationResultColor: SwiftUI.Color {
        guard let result = keyValidationResult else { return SwiftUI.Color.primary }
        return result.contains("Success") ? SwiftUI.Color.green : SwiftUI.Color.red
    }
    
    var validationResultIcon: String {
        guard let result = keyValidationResult else { return "" }
        return result.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill"
    }
    
    // MARK: - Helper Methods (same as original)
    
    func getLevelDescription(for level: UserLevel) -> String {
        switch level {
        case .beginner:
            return "I'm just starting to learn \(selectedLanguage.rawValue)"
        case .intermediate:
            return "I can have basic conversations in \(selectedLanguage.rawValue)"
        }
    }
}

// MARK: - Test Notification Observer

class TestNotificationObserver {
    private var observations: [NSObjectProtocol] = []
    private(set) var receivedNotifications: [(name: Notification.Name, object: Any?)] = []
    
    func observe(name: Notification.Name, object: Any? = nil, using block: ((Notification) -> Void)? = nil) {
        let observation = NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] notification in
            self?.receivedNotifications.append((name: notification.name, object: notification.object))
            block?(notification)
        }
        observations.append(observation)
    }
    
    func reset() {
        receivedNotifications.removeAll()
    }
    
    deinit {
        observations.forEach { NotificationCenter.default.removeObserver($0) }
    }
}
import Foundation
import SwiftUI
import Combine
import OpenAIClientKit
import SecureStoreKit

@MainActor
final class OnboardingViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var currentStep = 0
    @Published var selectedLanguage: Language = .spanish
    @Published var selectedLevel: UserLevel = .beginner
    @Published var apiKey: String = ""
    @Published var isValidatingKey = false
    @Published var keyValidationResult: String?
    @Published var showError = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Load existing API key from Keychain if available
        self.apiKey = KeychainHelper.load() ?? ""
    }
    
    // MARK: - Navigation Methods
    
    func selectLanguage(_ language: Language) {
        selectedLanguage = language
        moveToStep(1)
    }
    
    func selectLevel(_ level: UserLevel) {
        selectedLevel = level
        moveToStep(2)
    }
    
    func moveToStep(_ step: Int) {
        withAnimation(.easeInOut(duration: Constants.AnimationDurations.short)) {
            currentStep = step
        }
    }
    
    func goBack() {
        withAnimation(.easeInOut(duration: Constants.AnimationDurations.short)) {
            if currentStep > 0 {
                currentStep -= 1
            }
        }
    }
    
    // MARK: - API Key Handling
    
    func pasteFromClipboard() {
        if let pasteboardString = UIPasteboard.general.string {
            apiKey = pasteboardString
        }
    }
    
    func validateAndComplete() async {
        isValidatingKey = true
        keyValidationResult = nil
        
        do {
            // Save the key first
            try KeychainHelper.save(apiKey, sync: .local)
            
            // Validate with OpenAI
            _ = try await LLMClient.shared.validateAPIKey(for: .chatGPT)
            
            keyValidationResult = Constants.Text.Validation.apiKeySuccess
            isValidatingKey = false
            
            // Complete onboarding after a short delay
            try await Task.sleep(nanoseconds: Constants.AnimationDurations.extraLongNanoseconds)
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
        // Save preferences to UserDefaults using type-safe extensions
        UserDefaults.standard.selectedLanguage = selectedLanguage.rawValue
        UserDefaults.standard.userLevel = selectedLevel.rawValue
        UserDefaults.standard.hasCompletedOnboarding = true
        
        // Notify the view that onboarding is complete
        NotificationCenter.default.post(name: Constants.Notifications.onboardingCompleted, object: nil)
    }
    
    // MARK: - Validation Methods
    
    var isApiKeyEmpty: Bool {
        apiKey.isEmpty
    }
    
    var canContinue: Bool {
        !isApiKeyEmpty && !isValidatingKey
    }
    
    var validationResultColor: Color {
        guard let result = keyValidationResult else { return .primary }
        return result.contains("Success") ? .green : .red
    }
    
    var validationResultIcon: String {
        guard let result = keyValidationResult else { return "" }
        return result.contains("Success") ? Constants.SFSymbols.checkmark : Constants.SFSymbols.exclamation
    }
    
    // MARK: - Helper Methods
    
    func getLevelDescription(for level: UserLevel) -> String {
        switch level {
        case .beginner:
            return Constants.Text.Onboarding.beginnerDescription + selectedLanguage.rawValue
        case .intermediate:
            return Constants.Text.Onboarding.intermediateDescription + selectedLanguage.rawValue
        }
    }
}
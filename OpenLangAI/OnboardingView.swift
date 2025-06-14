import SwiftUI
import OpenAIClientKit
import SecureStoreKit

enum UserLevel: String, CaseIterable, Identifiable {
    case beginner = "Complete Beginner"
    case intermediate = "Intermediate"
    
    var id: String { rawValue }
}

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @State private var currentStep = 0
    @State private var selectedLanguage: Language = .spanish
    @State private var selectedLevel: UserLevel = .beginner
    @State private var apiKey: String = KeychainHelper.load() ?? ""
    @State private var isValidatingKey = false
    @State private var keyValidationResult: String?
    @State private var showError = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(currentStep + 1), total: 3)
                    .padding()
                
                // Content
                TabView(selection: $currentStep) {
                    // Step 1: Language Selection
                    VStack(spacing: 30) {
                        Text("Choose Your Target Language")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("What language would you like to practice?")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 15) {
                            ForEach(Language.allCases) { language in
                                Button(action: {
                                    selectedLanguage = language
                                    withAnimation {
                                        currentStep = 1
                                    }
                                }) {
                                    HStack {
                                        Text(language.flag)
                                            .font(.title)
                                        Text(language.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .tag(0)
                    
                    // Step 2: Level Selection
                    VStack(spacing: 30) {
                        Text("What's Your Level?")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("This helps us tailor conversations to your needs")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 20) {
                            ForEach(UserLevel.allCases) { level in
                                Button(action: {
                                    selectedLevel = level
                                    withAnimation {
                                        currentStep = 2
                                    }
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(level.rawValue)
                                            .font(.headline)
                                        Text(level == .beginner ? 
                                             "I'm just starting to learn \(selectedLanguage.rawValue)" :
                                             "I can have basic conversations in \(selectedLanguage.rawValue)")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding()
                                    .background(Color(UIColor.secondarySystemBackground))
                                    .cornerRadius(12)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        Button("Back") {
                            withAnimation {
                                currentStep = 0
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    .tag(1)
                    
                    // Step 3: API Key
                    VStack(spacing: 30) {
                        Text("OpenAI API Key")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your key is encrypted on-device and never leaves your phone")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text("API Key")
                                .font(.headline)
                            
                            HStack {
                                SecureField("sk-...", text: $apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                
                                Button(action: {
                                    if let pasteboardString = UIPasteboard.general.string {
                                        apiKey = pasteboardString
                                    }
                                }) {
                                    Image(systemName: "doc.on.clipboard")
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let result = keyValidationResult {
                                HStack {
                                    Image(systemName: result.contains("Success") ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundColor(result.contains("Success") ? .green : .red)
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(result.contains("Success") ? .green : .red)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            Button(action: validateAndComplete) {
                                if isValidatingKey {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Continue")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(apiKey.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(apiKey.isEmpty || isValidatingKey)
                            
                            Button("Skip for now") {
                                completeOnboarding()
                            }
                            .foregroundColor(.secondary)
                            
                            Button("Back") {
                                withAnimation {
                                    currentStep = 1
                                }
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(keyValidationResult ?? "An error occurred")
        }
    }
    
    private func validateAndComplete() {
        isValidatingKey = true
        keyValidationResult = nil
        
        Task {
            do {
                // Save the key first
                try KeychainHelper.save(apiKey, sync: .local)
                
                // Validate with OpenAI
                _ = try await LLMClient.shared.validateAPIKey(for: .chatGPT)
                
                await MainActor.run {
                    keyValidationResult = "Success! API key validated"
                    isValidatingKey = false
                    
                    // Complete onboarding after a short delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        completeOnboarding()
                    }
                }
            } catch {
                await MainActor.run {
                    keyValidationResult = error.localizedDescription
                    isValidatingKey = false
                    showError = true
                }
            }
        }
    }
    
    private func completeOnboarding() {
        // Save preferences
        UserDefaults.standard.set(selectedLanguage.rawValue, forKey: "selectedLanguage")
        UserDefaults.standard.set(selectedLevel.rawValue, forKey: "userLevel")
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        withAnimation {
            isOnboardingComplete = true
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
import SwiftUI

enum UserLevel: String, CaseIterable, Identifiable {
    case beginner = "Complete Beginner"
    case intermediate = "Intermediate"
    
    var id: String { rawValue }
}

struct OnboardingView: View {
    @Binding var isOnboardingComplete: Bool
    @StateObject private var viewModel = OnboardingViewModel()
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Progress indicator
                ProgressView(value: Double(viewModel.currentStep + 1), total: 3)
                    .padding()
                
                // Content
                TabView(selection: $viewModel.currentStep) {
                    // Step 1: Language Selection
                    VStack(spacing: 30) {
                        Text(Constants.Text.Onboarding.chooseLanguageTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(Constants.Text.Onboarding.chooseLanguageSubtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 15) {
                            ForEach(Language.allCases) { language in
                                Button(action: {
                                    viewModel.selectLanguage(language)
                                }) {
                                    HStack {
                                        Text(language.flag)
                                            .font(.title)
                                        Text(language.rawValue)
                                            .font(.headline)
                                        Spacer()
                                        Image(systemName: Constants.SFSymbols.chevronRight)
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
                        Text(Constants.Text.Onboarding.chooseLevelTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(Constants.Text.Onboarding.chooseLevelSubtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 20) {
                            ForEach(UserLevel.allCases) { level in
                                Button(action: {
                                    viewModel.selectLevel(level)
                                }) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(level.rawValue)
                                            .font(.headline)
                                        Text(viewModel.getLevelDescription(for: level))
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
                        
                        Button(Constants.Text.Onboarding.backButton) {
                            viewModel.goBack()
                        }
                        .foregroundColor(.blue)
                    }
                    .tag(1)
                    
                    // Step 3: API Key
                    VStack(spacing: 30) {
                        Text(Constants.Text.Onboarding.apiKeyTitle)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(Constants.Text.Onboarding.apiKeySubtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(alignment: .leading, spacing: 15) {
                            Text(Constants.Text.Onboarding.apiKeyPlaceholder)
                                .font(.headline)
                            
                            HStack {
                                SecureField(Constants.Text.Onboarding.apiKeySecureFieldPlaceholder, text: $viewModel.apiKey)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                
                                Button(action: {
                                    viewModel.pasteFromClipboard()
                                }) {
                                    Image(systemName: Constants.SFSymbols.clipboard)
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if let result = viewModel.keyValidationResult {
                                HStack {
                                    Image(systemName: viewModel.validationResultIcon)
                                        .foregroundColor(viewModel.validationResultColor)
                                    Text(result)
                                        .font(.caption)
                                        .foregroundColor(viewModel.validationResultColor)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        VStack(spacing: 15) {
                            Button(action: {
                                Task {
                                    await viewModel.validateAndComplete()
                                }
                            }) {
                                if viewModel.isValidatingKey {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text(Constants.Text.Onboarding.continueButton)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(viewModel.isApiKeyEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .disabled(!viewModel.canContinue)
                            
                            Button(Constants.Text.Onboarding.skipButton) {
                                viewModel.skipApiKey()
                            }
                            .foregroundColor(.secondary)
                            
                            Button(Constants.Text.Onboarding.backButton) {
                                viewModel.goBack()
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: viewModel.currentStep)
            }
        }
        .alert(Constants.Text.Onboarding.errorTitle, isPresented: $viewModel.showError) {
            Button(Constants.Text.Onboarding.okButton) { }
        } message: {
            Text(viewModel.keyValidationResult ?? Constants.Text.Onboarding.genericError)
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.Notifications.onboardingCompleted)) { _ in
            withAnimation {
                isOnboardingComplete = true
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isOnboardingComplete: .constant(false))
    }
}
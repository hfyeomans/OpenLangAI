import SwiftUI
import OpenAIClientKit
import SecureStoreKit

struct ContentView: View {
    @State private var selectedProvider: LLMProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .chatGPT
    @State private var apiKey: String = ""
    @State private var selectedLanguage: Language = .spanish
    @State private var testResult: String?
    @State private var showingComingSoonAlert = false
    @State private var selectedUnavailableProvider: LLMProvider?
    @State private var savedProviderKeys: Set<LLMProvider> = []
    
    // Define which providers are currently implemented
    private let implementedProviders: Set<LLMProvider> = [.chatGPT]
    
    private func providerDisplayName(for provider: LLMProvider) -> String {
        if implementedProviders.contains(provider) {
            return provider.rawValue
        } else {
            return "\(provider.rawValue) (Coming Soon)"
        }
    }
    
    private func isProviderAvailable(_ provider: LLMProvider) -> Bool {
        implementedProviders.contains(provider)
    }
    
    private func loadApiKey(for provider: LLMProvider) {
        apiKey = KeychainHelper.load(provider: provider.rawValue) ?? ""
    }
    
    private func updateSavedProviderKeys() {
        savedProviderKeys = Set(LLMProvider.allCases.filter { KeychainHelper.hasKey(for: $0.rawValue) })
    }
    
    private func apiKeyPlaceholder(for provider: LLMProvider) -> String {
        switch provider {
        case .chatGPT:
            return "sk-..."
        case .claude:
            return "sk-ant-..."
        case .gemini:
            return "AIza..."
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("LLM Provider")) {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            HStack {
                                Text(providerDisplayName(for: provider))
                                    .foregroundColor(isProviderAvailable(provider) ? .primary : .secondary)
                                Spacer()
                                if savedProviderKeys.contains(provider) {
                                    Image(systemName: "key.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedProvider) { newValue in
                        if isProviderAvailable(newValue) {
                            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedProvider")
                            loadApiKey(for: newValue)
                        } else {
                            // Show alert and revert to previous available provider
                            selectedUnavailableProvider = newValue
                            showingComingSoonAlert = true
                            // Revert to ChatGPT as it's the only implemented provider
                            selectedProvider = .chatGPT
                        }
                    }
                }

                Section(header: Text("API Key for \(selectedProvider.rawValue)")) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Provider-specific instructions
                        switch selectedProvider {
                        case .chatGPT:
                            Text("Enter your OpenAI API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .claude:
                            Text("Enter your Anthropic API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        case .gemini:
                            Text("Enter your Google AI API Key")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Show if a key is already saved
                        if savedProviderKeys.contains(selectedProvider) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("API key saved for \(selectedProvider.rawValue)")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        SecureField("Enter API Key (\(apiKeyPlaceholder(for: selectedProvider)))", text: $apiKey)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        
                        HStack {
                            Button("Save Key") {
                                do {
                                    try KeychainHelper.save(apiKey, provider: selectedProvider.rawValue, sync: .local)
                                    updateSavedProviderKeys()
                                } catch {
                                    print("Failed to save API key: \(error)")
                                }
                            }
                            .disabled(!isProviderAvailable(selectedProvider) || apiKey.isEmpty)
                            
                            if savedProviderKeys.contains(selectedProvider) && !apiKey.isEmpty {
                                Button("Delete Key") {
                                    do {
                                        try KeychainHelper.delete(provider: selectedProvider.rawValue)
                                        apiKey = ""
                                        updateSavedProviderKeys()
                                    } catch {
                                        print("Failed to delete API key: \(error)")
                                    }
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                }

                Section(header: Text("Language")) {
                    Picker("Learning Language", selection: $selectedLanguage) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }

                if let result = testResult {
                    Section(header: Text("Test Result")) {
                        Text(result)
                    }
                }

                Button("Test Connection") {
                    Task {
                        let response = await LLMClient.shared.testConnection(to: selectedProvider)
                        testResult = response
                    }
                }
                .disabled(!isProviderAvailable(selectedProvider))
            }
            .navigationTitle("OpenLangAI")
            .alert("Coming Soon", isPresented: $showingComingSoonAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if let provider = selectedUnavailableProvider {
                    Text("\(provider.rawValue) support is coming soon! Currently, only ChatGPT is available.")
                }
            }
            .onAppear {
                // Initialize with saved API key for selected provider
                loadApiKey(for: selectedProvider)
                // Update which providers have saved keys
                updateSavedProviderKeys()
            }
        }
    }
}

#Preview {
    ContentView()
}

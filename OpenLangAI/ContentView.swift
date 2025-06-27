import SwiftUI
import OpenAIClientKit
import SecureStoreKit

struct ContentView: View {
    @State private var selectedProvider: LLMProvider = LLMProvider(rawValue: UserDefaults.standard.string(forKey: "selectedProvider") ?? "") ?? .chatGPT
    @State private var apiKey: String = KeychainHelper.load() ?? ""
    @State private var selectedLanguage: Language = .spanish
    @State private var testResult: String?
    @State private var showingComingSoonAlert = false
    @State private var selectedUnavailableProvider: LLMProvider?
    
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

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("LLM Provider")) {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            HStack {
                                Text(providerDisplayName(for: provider))
                                    .foregroundColor(isProviderAvailable(provider) ? .primary : .secondary)
                            }
                            .tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: selectedProvider) { newValue in
                        if isProviderAvailable(newValue) {
                            UserDefaults.standard.set(newValue.rawValue, forKey: "selectedProvider")
                        } else {
                            // Show alert and revert to previous available provider
                            selectedUnavailableProvider = newValue
                            showingComingSoonAlert = true
                            // Revert to ChatGPT as it's the only implemented provider
                            selectedProvider = .chatGPT
                        }
                    }
                }

                Section(header: Text("API Key")) {
                    if selectedProvider == .chatGPT {
                        Text("Enter your OpenAI API Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    SecureField("Enter API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button("Save Key") {
                        try? KeychainHelper.save(apiKey, sync: .local)
                    }
                    .disabled(!isProviderAvailable(selectedProvider))
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
        }
    }
}

#Preview {
    ContentView()
}

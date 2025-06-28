import SwiftUI
import OpenAIClientKit
import SecureStoreKit

struct ContentView: View {
    @State private var selectedProvider: LLMProvider = .chatGPT
    @State private var apiKey: String = KeychainHelper.load() ?? ""
    @State private var selectedLanguage: Language = .spanish
    @State private var testResult: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(Constants.Text.Settings.llmProvider)) {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }

                Section(header: Text(Constants.Text.Settings.apiKey)) {
                    SecureField("Enter API Key", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button("Save Key") {
                        try? KeychainHelper.save(apiKey, sync: .local)
                    }
                }

                Section(header: Text(Constants.Text.Settings.language)) {
                    Picker("Learning Language", selection: $selectedLanguage) {
                        ForEach(Language.allCases) { lang in
                            Text(lang.rawValue).tag(lang)
                        }
                    }
                }

                if let result = testResult {
                    Section(header: Text(Constants.Text.Settings.testResult)) {
                        Text(result)
                    }
                }

                Button("Test Connection") {
                    Task {
                        let response = await LLMClient.shared.testConnection(to: selectedProvider)
                        testResult = response
                    }
                }
            }
            .navigationTitle("OpenLangAI")
        }
    }
}

#Preview {
    ContentView()
}

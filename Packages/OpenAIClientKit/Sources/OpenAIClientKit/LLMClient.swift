import Foundation
import SecureStoreKit

public enum LLMProvider: String, CaseIterable, Identifiable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"
    case gemini = "Gemini"

    public var id: String { rawValue }
}

public final class LLMClient {
    public static let shared = LLMClient()
    
    private var openAI: OpenAIClient {
        let apiKey = KeychainHelper.load()
        return OpenAIClient(apiKey: apiKey)
    }
    
    public func sendMessage(_ message: String, provider: LLMProvider, language: String) async throws -> String {
        switch provider {
        case .chatGPT:
            return try await openAI.sendChat(prompt: message, language: language)
        case .claude:
            // TODO: Implement Claude API
            throw LLMError.providerNotImplemented("Claude")
        case .gemini:
            // TODO: Implement Gemini API
            throw LLMError.providerNotImplemented("Gemini")
        }
    }
    
    public func validateAPIKey(for provider: LLMProvider) async throws -> Bool {
        switch provider {
        case .chatGPT:
            return try await openAI.validateAPIKey()
        case .claude:
            // TODO: Implement Claude API validation
            throw LLMError.providerNotImplemented("Claude")
        case .gemini:
            // TODO: Implement Gemini API validation
            throw LLMError.providerNotImplemented("Gemini")
        }
    }

    public func testConnection(to provider: LLMProvider) async -> String {
        do {
            switch provider {
            case .chatGPT:
                _ = try await openAI.validateAPIKey()
                return "Successfully connected to OpenAI"
            case .claude:
                return "Claude: Not yet implemented"
            case .gemini:
                return "Gemini: Not yet implemented"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

public enum LLMError: LocalizedError {
    case providerNotImplemented(String)
    
    public var errorDescription: String? {
        switch self {
        case .providerNotImplemented(let provider):
            return "\(provider) provider is not yet implemented."
        }
    }
}

import Foundation

public enum LLMProvider: String, CaseIterable, Identifiable {
    case chatGPT = "ChatGPT"
    case claude = "Claude"
    case gemini = "Gemini"

    public var id: String { rawValue }
}

public final class LLMClient {
    public static let shared = LLMClient()
    private let openAI = OpenAIClient()

    public func testConnection(to provider: LLMProvider) async -> String {
        do {
            switch provider {
            case .chatGPT:
                return try await openAI.sendChat(prompt: "ping")
            case .claude:
                return "Claude: ping"
            case .gemini:
                return "Gemini: ping"
            }
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }
}

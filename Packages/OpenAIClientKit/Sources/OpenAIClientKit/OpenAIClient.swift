import Foundation

public final class OpenAIClient {
    public init() {}

    public func sendChat(prompt: String) async throws -> String {
        // TODO: integrate OpenAI Chat Completion API
        return "Echo: \(prompt)"
    }
}

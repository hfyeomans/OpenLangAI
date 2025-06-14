import Foundation

public final class OpenAIClient {
    private let apiKey: String?
    private let endpoint = "https://api.openai.com/v1/chat/completions"
    private let model = "gpt-4o"
    
    public init(apiKey: String? = nil) {
        self.apiKey = apiKey
    }
    
    public func sendChat(prompt: String, language: String? = nil, systemPrompt: String? = nil) async throws -> String {
        guard let apiKey = apiKey else {
            throw OpenAIError.missingAPIKey
        }
        
        var messages: [[String: String]] = []
        
        // Add system prompt for language tutoring
        let defaultSystemPrompt = systemPrompt ?? "You are a patient language tutor. Speak only in \(language ?? "the target language") unless explicitly asked to translate or explain in English. Keep responses conversational and appropriate for language learning."
        messages.append(["role": "system", "content": defaultSystemPrompt])
        
        // Add user message
        messages.append(["role": "user", "content": prompt])
        
        let requestBody: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 500
        ]
        
        guard let url = URL(string: endpoint) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            if let choices = json?["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            throw OpenAIError.invalidResponseFormat
            
        case 401:
            throw OpenAIError.invalidAPIKey
            
        case 429:
            throw OpenAIError.rateLimitExceeded
            
        case 500...599:
            throw OpenAIError.serverError
            
        default:
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw OpenAIError.apiError(message)
            }
            throw OpenAIError.unknownError(statusCode: httpResponse.statusCode)
        }
    }
    
    public func validateAPIKey() async throws -> Bool {
        // Send a minimal test request to validate the API key
        _ = try await sendChat(prompt: "Hello", systemPrompt: "Reply with 'API key validated' in exactly 3 words.")
        return true
    }
}

public enum OpenAIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case invalidResponseFormat
    case invalidAPIKey
    case rateLimitExceeded
    case serverError
    case apiError(String)
    case unknownError(statusCode: Int)
    
    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Please add your API key in settings."
        case .invalidURL:
            return "Invalid API endpoint URL."
        case .invalidResponse:
            return "Invalid response from OpenAI API."
        case .invalidResponseFormat:
            return "Unexpected response format from OpenAI API."
        case .invalidAPIKey:
            return "Invalid API key. Please check your OpenAI API key."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .serverError:
            return "OpenAI server error. Please try again later."
        case .apiError(let message):
            return "OpenAI API error: \(message)"
        case .unknownError(let statusCode):
            return "Unknown error occurred (status code: \(statusCode))."
        }
    }
}

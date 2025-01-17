import Foundation



protocol LLMProtocolProvider {

    init(configuration: LLMServiceConfiguration)

    func getAvailableModels(completion: @escaping (Result<[LLMAvailableModelEntry], LLMError>) -> Void)
    
    func sendMessage(_ messages: [LLMMessage], modelProfile: LLMModelProfile) async throws -> LLMResponse

    func streamMessage(
        _ messages: [LLMMessage],
        modelProfile: LLMModelProfile,
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Result<LLMResponse, LLMError>) -> Void
    ) async throws
}

// MARK: - Utility Extensions
extension LLMProtocolProvider {
    // Move the token counting utility here as it could be useful for all services
    func estimateTokenCount(for text: String) -> Int {
        // This is a very rough estimate - should be replaced with proper tokenizer
        // Most LLMs use different tokenization methods
        let words = text.split(separator: " ")
        return words.count * 4/3 // Rough approximation
    }
}

// MARK: - Common Properties
extension LLMProtocolProvider {
    var decoder: JSONDecoder { JSONDecoder() }
    var encoder: JSONEncoder { JSONEncoder() }
}

// MARK: - Error Handling
extension LLMProtocolProvider {
    static func handleHTTPResponse(_ response: URLResponse) -> LLMError? {
        guard let httpResponse = response as? HTTPURLResponse else {
            return .invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            return nil
        case 401:
            return .authenticationError
        case 429:
            return .rateLimitExceeded
        case 400:
            return .contextLengthExceeded
        default:
            return .serverError("Status code: \(httpResponse.statusCode)")
        }
    }
}

// MARK: - Request Creation
extension LLMProtocolProvider {
    func createBaseRequest(url: URL, method: String = "POST") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

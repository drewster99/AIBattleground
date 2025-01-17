import Foundation

struct ClaudeRequest: Encodable {
    let model: String
    let messages: [Message]
    let maxTokens: Int
    let temperature: Double?
    let stream: Bool
    
    struct Message: Encodable {
        let role: String
        let content: String
    }
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct ClaudeResponse: Decodable {
    struct Content: Decodable {
        let type: String
        let text: String
    }
    
    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    let id: String
    let type: String
    let role: String
    let model: String
    let content: [Content]
    let stop_reason: String?
    let stop_sequence: String?
    let usage: Usage
}

class ClaudeProtocolDriver: LLMProtocolProvider {
    public private(set) var configuration: LLMServiceConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let anthropicVersion = "2023-06-01"

    required init(configuration: LLMServiceConfiguration) {
        self.configuration = configuration
        self.session = .shared
    }

    // convenience

    private var baseURL: URL {
        return configuration.endpointURL
    }

    private var serviceName: String {
        guard !configuration.name.isEmpty else {
            fatalError("Invalid empty service name")
        }
        return configuration.name
    }

    func sendMessage(_ messages: [LLMMessage], modelProfile: LLMModelProfile) async throws -> LLMResponse {
        guard let request = try await createRequest(for: messages, modelProfile: modelProfile) else {
            throw LLMError.invalidEndpoint
        }
        
        let (data, response) = try await session.data(for: request)
        
        if let error = Self.handleHTTPResponse(response) {
            throw error
        }
        
        let claudeResponse = try decoder.decode(ClaudeResponse.self, from: data)
        return convertToLLMResponse(claudeResponse)
    }
    
    private func createRequest(for messages: [LLMMessage], modelProfile: LLMModelProfile, streaming: Bool = false) async throws -> URLRequest? {
        let url = baseURL.appendingPathComponent("messages")
        var request = createBaseRequest(url: url)
        if let apiKey = await configuration.getApiKey() {
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        }
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        
        let claudeRequest = ClaudeRequest(
            model: modelProfile.modelEntry.id,
            messages: messages.map { message in 
                ClaudeRequest.Message(
                    role: message.role == .system ? "assistant" : message.role.rawValue,
                    content: message.content
                )
            },
            maxTokens: modelProfile.modelSettings.maxTokens ?? 1024,
            temperature: modelProfile.modelSettings.temperature,
            stream: streaming
        )
        
        request.httpBody = try encoder.encode(claudeRequest)
        return request
    }
    
    private func convertToLLMResponse(_ claudeResponse: ClaudeResponse) -> LLMResponse {
        return LLMResponse(
            content: claudeResponse.content.first?.text ?? "",
            totalTokens: claudeResponse.usage.inputTokens + claudeResponse.usage.outputTokens,
            promptTokens: claudeResponse.usage.inputTokens,
            completionTokens: claudeResponse.usage.outputTokens,
            finishReason: claudeResponse.stop_reason
        )
    }
    
    func streamMessage(
        _ messages: [LLMMessage],
        modelProfile: LLMModelProfile,  
        onReceive: @escaping (String) -> Void,
        onComplete: @escaping (Result<LLMResponse, LLMError>) -> Void
    ) async throws {
        var request = try await createRequest(for: messages, modelProfile: modelProfile, streaming: true)
        request?.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        guard let request = request else {
            onComplete(.failure(.invalidEndpoint))
            return
        }
        
        var streamedContent: [String] = []
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                onComplete(.failure(.networkError(error)))
                return
            }
            
            guard let data = data,
                  let text = String(data: data, encoding: .utf8) else {
                onComplete(.failure(.invalidResponse))
                return
            }
            
            onReceive(text)
            streamedContent.append(text)
            let response = LLMResponse(
                content: streamedContent.joined(),
                isComplete: true,
                streamedContent: streamedContent
            )
            onComplete(.success(response))
        }
        task.resume()
    }
    
    private struct ModelsResponse: Decodable {
        struct Model: Decodable {
            let id: String
            let display_name: String
            let type: String
            let created_at: String
        }
        
        let data: [Model]
        let has_more: Bool
        let first_id: String
        let last_id: String
    }
    
    func getAvailableModels(completion: @escaping (Result<[LLMAvailableModelEntry], LLMError>) -> Void) {
        var request = createBaseRequest(
            url: baseURL.appending(component: "models"),
            method: "GET"
        )
        Task.detached { [configuration, anthropicVersion, serviceName, session] in
            if let apiKey = await configuration.getApiKey() {
                request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            }
            request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
            
            let task = session.dataTask(with: request) { data, response, error in
                if let error = error {
                    completion(.failure(.networkError(error)))
                    return
                }
                
                guard let response = response else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                if let error = Self.handleHTTPResponse(response) {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                switch httpResponse.statusCode {
                case 200:
                    do {
                        let modelsResponse = try JSONDecoder().decode(ModelsResponse.self, from: data ?? Data())
                        let models = modelsResponse.data.map { model in
                            LLMAvailableModelEntry(
                                id: model.id,
                                displayName: model.display_name,
                                provider: "Anthropic",
                                created: ISO8601DateFormatter().date(from: model.created_at),
                                description: nil
                            )
                        }
                        completion(.success(models))
                    } catch {
                        print("\(serviceName) decoding error: \(error)")
                        completion(.failure(.invalidResponse))
                    }
                case 401:
                    completion(.failure(.authenticationError))
                default:
                    completion(.failure(.serverError("Status code: \(httpResponse.statusCode)")))
                }
            }
            task.resume()
        }
    }
} 

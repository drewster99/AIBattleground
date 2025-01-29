import Foundation

struct OpenAIRequest: Encodable {
    let model: String
    let messages: [[String: String]]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
        case stream
    }
}

struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        let index: Int
        let message: OpenAIMessage
        let finishReason: String?
//        let logProbs: ??
        enum CodingKeys: String, CodingKey {
            case index = "index"
            case message = "message"
            case finishReason = "finish_reason"
        }
    }

    struct Usage: Decodable {
        let promptTokens: Int
        let completionTokens: Int
        let totalTokens: Int
        let promptTokensDetails: PromptTokensDetails?
        let completionTokensDetails: CompletionTokensDetails?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case promptTokensDetails = "prompt_tokens_details"
            case completionTokensDetails = "completion_tokens_details"
        }

        struct PromptTokensDetails: Decodable {
            let cachedTokens: Int
            let audioTokens: Int

            enum CodingKeys: String, CodingKey {
                case cachedTokens = "cached_tokens"
                case audioTokens = "audio_tokens"
            }
        }

        struct CompletionTokensDetails: Decodable {
            let reasoningTokens: Int
            let audioTokens: Int
            let acceptedPredictionTokens: Int
            let rejectedPredictionTokens: Int

            enum CodingKeys: String, CodingKey {
                case reasoningTokens = "reasoning_tokens"
                case audioTokens = "audio_tokens"
                case acceptedPredictionTokens = "accepted_prediction_tokens"
                case rejectedPredictionTokens = "rejected_prediction_tokens"
            }
        }
    }

    struct OpenAIMessage: Decodable {
        let role: String
        let content: String
        let refusal: String?
    }

    var id: String?
    var object: String?
    var created: Date?
    var model: String?
    let choices: [Choice]
    let usage: Usage
    let serviceTier: String?
    let systemFingerprint: String?

    enum CodingKeys: String, CodingKey {
        case id = "id"
        case object = "object"
        case created = "created"
        case model = "model"
        case choices = "choices"
        case usage = "usage"
        case serviceTier = "service_tier"
        case systemFingerprint = "system_fingerprint"
    }
}

class OpenAIProtocolDriver: LLMProtocolProvider {
    public private(set) var configuration: LLMServiceConfiguration
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    required init(configuration: LLMServiceConfiguration) {
        self.configuration = configuration
        self.session = .shared
        self.decoder.dateDecodingStrategy = .secondsSince1970
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

    private func createRequest(for messages: [LLMMessage], modelProfile: LLMModelProfile, streaming: Bool = false) async throws -> URLRequest? {
        let url = baseURL.appending(component: "chat").appending(component: "completions")
        var request = createBaseRequest(url: url)
        if let apiKey = await configuration.getApiKey() {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let openAIRequest = OpenAIRequest(
            model: modelProfile.modelEntry.id,
            messages: messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            temperature: modelProfile.modelSettings.temperature,
            maxTokens: modelProfile.modelSettings.maxTokens,
            stream: streaming
        )

        request.httpBody = try encoder.encode(openAIRequest)
        return request
    }

    private func convertToLLMResponse(_ openAIResponse: OpenAIResponse) -> LLMResponse {
        guard let choice = openAIResponse.choices.first else {
            return LLMResponse(content: "")
        }

        // Note: OpenAI includes an "id" field (string) in its response.
        // Google Gemini's OpenAI compatability endpoint does not include that field.
        // Luckily, we don't use it at this time.
        return LLMResponse(
            content: choice.message.content,
            totalTokens: openAIResponse.usage.totalTokens,
            promptTokens: openAIResponse.usage.promptTokens,
            completionTokens: openAIResponse.usage.completionTokens,
            finishReason: choice.finishReason
        )
    }

    func sendMessage(_ messages: [LLMMessage], modelProfile: LLMModelProfile) async throws -> LLMResponse {
        guard let request = try await createRequest(for: messages, modelProfile: modelProfile) else {
            throw LLMError.invalidEndpoint
        }

        print("""
        
        🌐 Outgoing Request:
        URL: \(request.url?.absoluteString ?? "nil")
        Method: \(request.httpMethod ?? "nil")
        
        Headers:
        \(request.allHTTPHeaderFields?.map { "  \($0.key): \($0.value)" }.joined(separator: "\n") ?? "  none")
        
        Body:
        \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "none")
        
        """)

        let (data, response) = try await session.data(for: request)

        print("""
        * Response data (\(data.count) bytes):
        \(String(data: data, encoding: .utf8) ?? "<INTERNAL ERROR (NOT FROM INTERNET) - RESPONSE IS NOT UTF8>")
        """)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
            return convertToLLMResponse(openAIResponse)
        case 401:
            throw LLMError.authenticationError
        case 429:
            throw LLMError.rateLimitExceeded
        case 400:
            throw LLMError.contextLengthExceeded
        default:
            throw LLMError.serverError("Status code: \(httpResponse.statusCode)")
        }
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
                let text = String(data: data, encoding: .utf8)
            else {
                onComplete(.failure(.invalidResponse))
                return
            }

            // Process the chunk
            onReceive(text)
            streamedContent.append(text)

            // Create final response
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
            let created: Int?
            let owned_by: String
            let object: String
            let display_name: String?  // Some models have display names
            let description: String?  // And descriptions
        }
        let data: [Model]
    }

    private func createDisplayName(from modelId: String) -> String {
        // Convert "gpt-3.5-turbo" to "GPT-3.5 Turbo"
        let parts = modelId.split(separator: "-")
        let formatted = parts.map { part in
            if part.allSatisfy({ $0.isNumber || $0 == "." }) {
                return part.description  // Keep numbers as-is
            }
            return part.prefix(1).uppercased() + part.dropFirst()
        }
        return formatted.joined(separator: " ")
    }

    func getAvailableModels(completion: @escaping (Result<[LLMAvailableModelEntry], LLMError>) -> Void) {
        var request = createBaseRequest(
            url: baseURL.appending(component: "models"),
            method: "GET"
        )
        Task.detached { [configuration, serviceName, session] in
            var hasNonEmptyApiKey = false
            if let apiKey = await configuration.getApiKey() {
                request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                if !apiKey.isEmpty {
                    hasNonEmptyApiKey = true
                }
            }

            if request.url?.absoluteString == "https://generativelanguage.googleapis.com/v1beta/openai/models" {
                // Google Gemini - OpenAI api compat doesn't work for this call
                guard hasNonEmptyApiKey else {
                    completion(.failure(.authenticationError))
                    return
                }

                let modelNames: [String] = [
                    "gemini-2.0-flash-exp",
                    "gemini-1.5-flash",
                    "gemini-1.5-flash-8b",
                    "gemini-1.5-pro"
                ]
                let results = modelNames.map { modelName in
                    LLMAvailableModelEntry(id: modelName,
                                           displayName: nil,
                                           provider: "Google Gemini",
                                           created: .now,
                                           description: "Added from hardcoded list - Gemini's OpenAI compatability doesn't support the \"models\" endpoint")
                }
                completion(.success(results))
                return
            }
            print("""
        
        🌐 Outgoing Request:
        URL: \(request.url?.absoluteString ?? "nil")
        Method: \(request.httpMethod ?? "nil")
        
        Headers:
        \(request.allHTTPHeaderFields?.map { "  \($0.key): \($0.value)" }.joined(separator: "\n") ?? "  none")
        
        Body:
        \(String(data: request.httpBody ?? Data(), encoding: .utf8) ?? "none")
        
        """)
            let task = session.dataTask(with: request) { [serviceName] data, response, error in
                // Debug print raw response
                if let data = data, let responseStr = String(data: data, encoding: .utf8) {
                    print("\n=== Raw \(serviceName) Models Response ===")
                    print(responseStr)
                    print("=====================================\n")
                }

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

                do {
                    let modelsResponse = try JSONDecoder().decode(
                        ModelsResponse.self, from: data ?? Data())
                    let models = modelsResponse.data
                        .filter { !$0.id.contains("audio") }  // Filter out audio models
                        .map { model in
                            let created: Date
                            if let createdTimeInterval = model.created {
                                created = Date(timeIntervalSince1970: TimeInterval(createdTimeInterval))
                            } else {
                                // Some 3rd parties who purport to use the OpenAI API don't return this field
                                created = .distantPast
                            }
                            return LLMAvailableModelEntry(
                                id: model.id,
                                displayName: model.display_name,
                                provider: serviceName,
                                created: created,
                                description: model.description
                            )
                        }
                    completion(.success(models))
                } catch {
                    print("\(serviceName) decoding error: \(error)")
                    completion(.failure(.invalidResponse))
                }
            }
            task.resume()
        }
    }
}

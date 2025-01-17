import Foundation


struct LLMServiceConfiguration: Identifiable, Hashable, Equatable, Codable {
    let id: String
    let name: String
    let comment: String?
    let lastUpdate: Date
    let protocolDriver: LLMProtocolDriverDescription
    let endpointURL: URL
    let thumbnailImageURL: URL?
    let username: String?

    public var apiKey: String? {
        get {
            let key = LLMCredentialKeyManager.shared.getApiKeySynchronously(credentialID: id)
            return key
        }
    }

    public func getApiKey() async -> String? {
        await LLMCredentialKeyManager.shared.getApiKey(credentialID: id)
    }

    public func setApiKey(_ apiKey: String?) async throws {
        let id = self.id
        async let result: () = try await LLMCredentialKeyManager.shared.setApiKey(apiKey, credentialID: id)
        do {
            try await result
        }
    }

    init(
        id: String? = nil,
        name: String,
        comment: String?,
        username: String?,
        protocolDriver: LLMProtocolDriverDescription,
        endpointURL: URL,
        thumbnailImageURL: URL?,
        lastUpdate: Date = .now
    ) {
        if let id, id.count > 3 {
            self.id = id
        } else {
            self.id = "\(protocolDriver.id):\(UUID().uuidString)"
        }
        self.name = name
        self.comment = comment
        self.username = username
        self.protocolDriver = protocolDriver
        self.endpointURL = endpointURL
        self.thumbnailImageURL = thumbnailImageURL
        self.lastUpdate = lastUpdate
    }

    static func == (lhs: LLMServiceConfiguration, rhs: LLMServiceConfiguration) -> Bool {
        lhs.id == rhs.id
        && lhs.name == rhs.name
        && lhs.comment == rhs.comment
        && lhs.lastUpdate == rhs.lastUpdate
        && lhs.username == rhs.username
        && lhs.endpointURL == rhs.endpointURL
        && lhs.thumbnailImageURL == rhs.thumbnailImageURL
        && lhs.protocolDriver == rhs.protocolDriver
        && lhs.apiKey == rhs.apiKey
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(comment)
        hasher.combine(lastUpdate)
        hasher.combine(username)
        hasher.combine(endpointURL)
        hasher.combine(thumbnailImageURL)
        hasher.combine(protocolDriver)
        hasher.combine(apiKey)
    }
}

enum LLMServiceError: LocalizedError {
    case decodingError(Error)
    case encodingError(Error)

    var errorDescription: String? {
        switch self {
        case .decodingError(let error):
            return "Failed to decode credentials: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode credentials: \(error.localizedDescription)"
        }
    }
}

extension LLMServiceConfiguration {
    static public var defaultServiceConfigurations: [LLMServiceConfiguration] {
        var defaultServices: [LLMServiceConfiguration] = []

        // Automatically add any service that has its own protocol driver
        for protocolDriver in LLMProtocolDriverDescription.allCases {
            defaultServices.append(LLMServiceConfiguration(
                id: protocolDriver.rawValue,
                name: protocolDriver.displayName,
                comment: nil,
                username: nil,
                protocolDriver: protocolDriver,
                endpointURL: protocolDriver.defaultBaseURL,
                thumbnailImageURL: protocolDriver.imageURL,
                lastUpdate: .distantPast)
            )
        }

        // Add others we know about
        defaultServices.append(contentsOf:
                                [
                                    LLMServiceConfiguration(id: "GoogleGemini-openai-builtin",
                                                            name: "Gemini",
                                                            comment: "Google Gemini via OpenAI Compatibility endpoint",
                                                            username: nil,
                                                            protocolDriver: .openai,
                                                            endpointURL: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!,
                                                            thumbnailImageURL: URL(string: "https://google.com/favicon.ico"),
                                                            lastUpdate: .distantPast),
                                    LLMServiceConfiguration(id: "Deepseek-openai-builtin",
                                                            name: "Deepseek",
                                                            comment: nil,
                                                            username: nil,
                                                            protocolDriver: .openai,
                                                            endpointURL: URL(string: "https://api.deepseek.com/v1")!,
                                                            thumbnailImageURL: URL(string: "https://deepseek.com/favicon.ico"),
                                                            lastUpdate: .distantPast)
                                ]
        )
        return defaultServices
    }
}

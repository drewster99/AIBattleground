import Foundation

/// A description of an LLM protocol driver.
enum LLMProtocolDriverDescription: String, Codable, Hashable, Equatable, Identifiable, CaseIterable {
    case openai
    case claude

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .claude: return "Claude"
        }
    }
    var serviceType: LLMProtocolProvider.Type {
        switch self {
        case .openai: return OpenAIProtocolDriver.self
        case .claude: return ClaudeProtocolDriver.self
        }
    }
    var imageURL: URL? {
        switch self {
        case .openai: return URL(string: "https://openai.com/favicon.ico")
        case .claude: return URL(string: "https://claude.ai/favicon.ico")
        }
    }
    var defaultBaseURL: URL {
        switch self {
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .claude: return URL(string: "https://api.anthropic.com/v1")!
        }
    }
}
//struct LLMProtocolDriverDescription: Identifiable, Hashable, Equatable {
//    let id: String
//    let displayName: String
//    let serviceType: LLMServiceProtocol.Type  // Protocol metatype - cannot be synthesized
//    let imageURL: URL?
//
//    static func == (lhs: LLMProtocolDriverDescription, rhs: LLMProtocolDriverDescription) -> Bool {
//        lhs.id == rhs.id && lhs.displayName == rhs.displayName && lhs.serviceType == rhs.serviceType
//            && lhs.imageURL == rhs.imageURL
//    }
//
//    func hash(into hasher: inout Hasher) {
//        hasher.combine(id)
//        hasher.combine(displayName)
//        hasher.combine(String(describing: serviceType))
//        hasher.combine(imageURL)
//    }
//}

//extension LLMProtocolDriverDescription: CaseIterable {
//    static var allCases: [LLMProtocolDriverDescription] = [
//        LLMProtocolDriverDescription(
//            id: "openai",
//            displayName: "OpenAI",
//            serviceType: OpenAIService.self,
//            imageURL: URL(string: "https://openai.com/favicon.ico")
//        ),
//        LLMProtocolDriverDescription(
//            id: "claude",
//            displayName: "Anthropic Claude",
//            serviceType: ClaudeService.self,
//            imageURL: URL(string: "https://claude.ai/favicon.ico")
//        ),
//        LLMProtocolDriverDescription(
//            id: "deepseek",
//            displayName: "Deepseek",
//            serviceType: DeepSeekService.self,
//            imageURL: URL(string: "https://deepseek.com/favicon.ico")
//        ),
//    ]
//}

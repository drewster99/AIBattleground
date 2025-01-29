import Foundation

struct LLMResponse: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: LLMMessage
    let totalTokens: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let cacheReadInputTokens: Int?
    let cacheCreationInputTokens: Int?
    let finishReason: String?
    let refusal: String?

    // For streaming responses
    var isComplete: Bool
    var streamedContent: [String]
    
    init(
        id: UUID = UUID(),
        content: String,
        totalTokens: Int? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        cacheReadInputTokens: Int? = nil,
        cacheCreationInputTokens: Int? = nil,
        finishReason: String? = nil,
        isComplete: Bool = true,
        streamedContent: [String] = [],
        refusal: String? = nil
    ) {
        self.id = id
        self.timestamp = Date()
        self.message = LLMMessage(role: .assistant, content: content)
        self.totalTokens = totalTokens
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.cacheReadInputTokens = cacheReadInputTokens
        self.cacheCreationInputTokens = cacheCreationInputTokens
        self.finishReason = finishReason
        self.isComplete = isComplete
        self.streamedContent = streamedContent
        self.refusal = refusal
    }
    
    var fullContent: String {
        isComplete ? message.content : streamedContent.joined()
    }
} 

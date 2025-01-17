import Foundation

struct LLMResponse: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let message: LLMMessage
    let totalTokens: Int?
    let promptTokens: Int?
    let completionTokens: Int?
    let finishReason: String?
    
    // For streaming responses
    var isComplete: Bool
    var streamedContent: [String]
    
    init(
        id: UUID = UUID(),
        content: String,
        totalTokens: Int? = nil,
        promptTokens: Int? = nil,
        completionTokens: Int? = nil,
        finishReason: String? = nil,
        isComplete: Bool = true,
        streamedContent: [String] = []
    ) {
        self.id = id
        self.timestamp = Date()
        self.message = LLMMessage(role: .assistant, content: content)
        self.totalTokens = totalTokens
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.finishReason = finishReason
        self.isComplete = isComplete
        self.streamedContent = streamedContent
    }
    
    var fullContent: String {
        isComplete ? message.content : streamedContent.joined()
    }
} 
import Foundation

struct LLMMessage: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let role: MessageRole
    let content: String
    var tokenCount: Int?
    
    enum MessageRole: String, Codable {
        case system
        case user
        case assistant
        case function
    }
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        tokenCount: Int? = nil
    ) {
        self.id = id
        self.timestamp = Date()
        self.role = role
        self.content = content
        self.tokenCount = tokenCount
    }
} 
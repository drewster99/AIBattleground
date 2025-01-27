import Foundation
import SwiftUI



struct LLMMessage: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    var role: MessageRole
    var content: String
    var tokenCount: Int?

    enum MessageRole: Identifiable, Equatable, Codable, Hashable, RawRepresentable {
        init?(rawValue: String) {
            switch rawValue {
            case "system": self = .system
            case "user": self = .user
            case "assistant": self = .assistant
            default: self = .other(rawValue)
            }
        }

        case system
        case user
        case assistant
        // case function
        case other(String)

        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .system: return "System"
            case .user: return "User"
            case .assistant: return "AI"
            // case .function: return "Function"
            case .other(let value): return value
            }
        }

        var rawValue: String {
            switch self {
            case .system: return "system"
            case .user: return "user"
            case .assistant: return "assistant"
            case .other(let value): return value
            }
        }

        var backgroundColor: Color {
            switch self {
            case .system: return Color.orange
            case .user: return Color.blue
            case .assistant: return Color.green
            case .other: return Color.gray
            }
        }

        var sortRank: Int {
            switch self {
            case .system: 1
            case .user: 0
            case .assistant: 2
            case .other: 3
            }
        }
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

    static func empty() -> LLMMessage {
        .init(role: .user, content: "")
    }
}

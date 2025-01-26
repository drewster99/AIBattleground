import Foundation
import SwiftUI
import Combine

struct EditingMessageModel: Codable, Identifiable, Equatable, Hashable {
    var id: LLMMessage.ID { message.id }
    var preferredDisplayStyle: MessageDisplayStyle = .compact
    var isEditable: Bool = true
    var message: LLMMessage

    public init(rowMode: MessageDisplayStyle, isEditable: Bool, message: LLMMessage) {
        self.preferredDisplayStyle = rowMode
        self.isEditable = isEditable
        self.message = message
    }

    public init(_ message: LLMMessage, isEditable: Bool = true) {
        self.message = message
        self.isEditable = isEditable
    }

    public var debugDescription: String {
        let id = "\(id)".suffix(5)
        return "id: \(id), preferredDisplayStyle=\(preferredDisplayStyle.id): [\(message.role.rawValue)] \"\(message.content)\""
    }

    public static func empty() -> Self {
        let newMessage = EditingMessageModel(LLMMessage.empty())
        return newMessage
    }
}

extension Set where Element == LLMMessage.MessageRole {
    var inDisplayOrder: [LLMMessage.MessageRole] {
        self.sorted { (lhs, rhs) -> Bool in
            if lhs.sortRank == rhs.sortRank {
                return lhs.rawValue < rhs.rawValue
            } else {
                return lhs.sortRank < rhs.sortRank
            }
        }
    }
}

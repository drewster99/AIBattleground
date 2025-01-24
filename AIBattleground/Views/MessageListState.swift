import Foundation
import SwiftUI
import Combine

struct EditingMessageModel: Codable, Identifiable, Equatable, Hashable {
    var id: LLMMessage.ID { message.id }
    var rowMode: MessageRowMode = .compact
    var isEditable: Bool = true
    var message: LLMMessage

    public init(rowMode: MessageRowMode, isEditable: Bool, message: LLMMessage) {
        self.rowMode = rowMode
        self.isEditable = isEditable
        self.message = message
    }

    public init(_ message: LLMMessage, isEditable: Bool = true) {
        self.message = message
        self.isEditable = isEditable
    }

    public var debugDescription: String {
        let id = "\(id)".suffix(5)
        return "id: \(id), rowMode=\(rowMode.id): [\(message.role.rawValue)] \"\(message.content)\""
    }

    public static func empty() -> Self {
        let newMessage = EditingMessageModel(LLMMessage.empty())
        return newMessage
    }
}

class MessageListState: ObservableObject {
    @Published var editingMessages: [EditingMessageModel] = []

    private var areAnyRowsEditing: Bool {
        editingMessages.reduce(false) { $0 || $1.rowMode == .edit }
    }

    public init(_ messages: [LLMMessage], isEditable: Bool = true) {

        $editingMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] oldValue in
                guard let self else { return }

                print("* SINK: \(editingMessages.count) messages (was \(editingMessages.count)")
                for message in editingMessages {
                    print("* SINK:    \(message.debugDescription)")
                }

                guard !areAnyRowsEditing else { return }
                
                if editingMessages.isEmpty {
                    print("No messages.  Appending an empty one.")
                    appendEmptyMessage()
                } else if let finalMessage = editingMessages.last {
                    if finalMessage.message.content.isEmpty {
                        print("Final message has empty content.  Beginning editing on it \(finalMessage.debugDescription)")
                        beginEditing(finalMessage.id)
                    } else {
                        print("Final message DOES have content.  Appending empty one.")
                        appendEmptyMessage()
                    }
                } else {
                    fatalError("Should not happen.  Either the list is empty or we have a final message")
                }
            }
            .store(in: &cancellables)

        self.editingMessages = messages.map({ EditingMessageModel.init($0, isEditable: isEditable) })
    }

    private var cancellables: Set<AnyCancellable> = []

    public func appendEmptyMessage() {
        DispatchQueue.main.async {
            let newEmptyMessage = EditingMessageModel.empty()
            print("Append empty message: \(newEmptyMessage.debugDescription)")
            self.editingMessages.append(newEmptyMessage)
            self.beginEditing(newEmptyMessage.id)
        }
    }

    public func endAllEditing() {
        print("End all editing")
        let finalIndex = editingMessages.indices.last
        for index in editingMessages.indices {
            if editingMessages[index].rowMode == .edit {
                print("Ending editing for \(editingMessages[index])")
                editingMessages[index].rowMode = .compact
            }
        }
    }

    public func beginEditing(_ messageID: EditingMessageModel.ID) {
        DispatchQueue.main.async { [self] in
            print("Begin editing \(messageID)")
            let finalIndex = editingMessages.indices.last
            if let index = editingMessages.firstIndex(where: { $0.id == messageID }) {
                print("Found message id \(messageID) at index \(index)")
                if editingMessages[index].rowMode != .edit && editingMessages[index].isEditable {
                    print("About to edit \(editingMessages[index].debugDescription) after ending editing")
                    endAllEditing()
                    print("Done ending editing.  Setting to rowMode edit: \(editingMessages[index].debugDescription)")
                    editingMessages[index].rowMode = .edit
                }
            }
        }
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

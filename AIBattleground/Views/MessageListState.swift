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

    public init(_ message: LLMMessage) {
        self.message = message
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
    @Published var customRoles: Set<LLMMessage.MessageRole> = []
    @Published var isEditable: Bool = true
    @Published var messageBeingEdited: EditingMessageModel? = nil {
        didSet {
            print("messageBeingEdited = \(messageBeingEdited?.debugDescription ?? "nil")")
        }
    }

    private var areAnyRowsEditing: Bool {
        editingMessages.reduce(false) { $0 || $1.rowMode == .edit }
    }

    public init(_ messages: [LLMMessage], isEditable: Bool = true) {
        self.isEditable = isEditable

        $editingMessages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] oldValue in
                guard let self else { return }

                print("* SINK: \(editingMessages.count) messages (was \(editingMessages.count)")
                for message in editingMessages {
                    print("* SINK:    \(message.debugDescription)")
                }

                // Update customRoles, if needed
                var customRoles = self.customRoles
                var madeChanges = false
                for editingMessage in editingMessages {
                    if ![LLMMessage.MessageRole.user, .assistant, .system].contains(editingMessage.message.role) {
                        customRoles.insert(editingMessage.message.role)
                        madeChanges = true
                    }
                }
                if madeChanges { self.customRoles = customRoles }

                guard isEditable else {
                    if areAnyRowsEditing {
                        fatalError("need to stop things from editing")
                    }
                    return
                }

                guard !areAnyRowsEditing else { return }
                
                if editingMessages.isEmpty || (editingMessages.last?.message.content.isEmpty == false  && messageBeingEdited == nil) {
                    appendEmptyMessage()
                }
                let isAnythingEditing = editingMessages.reduce(false) { $0 || ($1.isEditable && $1.rowMode != .edit) }
                if !isAnythingEditing {
                    if let lastMessage = editingMessages.last {
                        beginEditing(lastMessage)
                    }
                }
            }
            .store(in: &cancellables)

        self.editingMessages = messages.map(EditingMessageModel.init)
    }

    private var cancellables: Set<AnyCancellable> = []

    public func appendEmptyMessage() {
        let newEmptyMessage = EditingMessageModel.empty()
        print("Append empty message: \(newEmptyMessage.debugDescription)")
        self.editingMessages.append(newEmptyMessage)
        if isEditable {
            self.beginEditing(newEmptyMessage)
        }
    }

    public func endEditing(_ message: EditingMessageModel) {
        guard let messageBeingEdited, messageBeingEdited.id == message.id else { return }
        self.messageBeingEdited = nil
    }
    public func beginEditing(_ message: EditingMessageModel) {
        messageBeingEdited = message
    }
    public func removeMessage(_ message: EditingMessageModel) {
        endEditing(message)
        print("Remove message: \(message.debugDescription)")
        editingMessages.removeAll(where: { $0.id == message.id })
    }

    public func nextRole(for role: LLMMessage.MessageRole) -> LLMMessage.MessageRole {
        var allRoles: Set<LLMMessage.MessageRole> = [.user, .assistant, .system]
        for role in customRoles {
            allRoles.insert(role)
        }
        let allRolesInOrder: [LLMMessage.MessageRole] = allRoles.inDisplayOrder

        if let index = allRolesInOrder.firstIndex(of: role) {
            let nextIndex = (index + 1) % allRolesInOrder.count
            return allRolesInOrder[nextIndex]
        } else {
            fatalError("Unknown role: \(role)")
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

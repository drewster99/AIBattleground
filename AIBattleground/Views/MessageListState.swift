import Foundation
import SwiftUI

class MessageListState: ObservableObject {
    @Published var messages: [LLMMessage]
    @Published var customRoles: Set<String>
    let isEditable: Bool
    
    init(messages: [LLMMessage] = [], isEditable: Bool = true) {
        self.messages = messages
        self.isEditable = isEditable
        self.customRoles = []
        
        if messages.isEmpty {
            let newMessage = LLMMessage(role: .user, content: "")
            self.messages.append(newMessage)
        }
    }
    
    private func updateCustomRoles() {
        var newRoles = Set<String>()
        for message in messages {
            if case let .other(role) = message.role {
                newRoles.insert(role)
            }
        }
        customRoles = newRoles
    }
    
    func moveMessage(from source: IndexSet, to destination: Int) {
        messages.move(fromOffsets: source, toOffset: destination)
    }
    
    func updateMessage(_ message: LLMMessage) {
        guard let index = messages.firstIndex(where: { $0.id == message.id }) else { return }
        messages[index] = message
        updateCustomRoles()
    }
    
    func addMessage(_ message: LLMMessage) {
        messages.append(message)
        updateCustomRoles()
    }
    
    func removeMessage(_ id: UUID) -> Bool {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return false }
        messages.remove(at: index)
        updateCustomRoles()
        return true
    }
    
    func cycleRole(for messageId: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        let currentRole = messages[index].role
        
        if case let .other(role) = currentRole {
            customRoles.remove(role)
        }
        
        let allRoles: [LLMMessage.MessageRole] = [.user, .assistant, .system] + customRoles.map { .other($0) }
        guard let currentIndex = allRoles.firstIndex(where: { $0 == currentRole }) else { return }
        let nextIndex = (currentIndex + 1) % allRoles.count
        let newRole = allRoles[nextIndex]
        
        let oldMessage = messages[index]
        let newMessage = LLMMessage(id: oldMessage.id, role: newRole, content: oldMessage.content)
        updateMessage(newMessage)
    }
    
    func addCustomRole(_ role: String) {
        customRoles.insert(role)
    }
} 

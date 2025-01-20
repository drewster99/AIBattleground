import SwiftUI

struct MessageListView: View {
    @EnvironmentObject private var state: MessageListState
    @State private var messageModes: [UUID: MessageRowMode] = [:]
    
    let confirmButtonTitle: String
    let onSubmit: ([LLMMessage]) -> Void
    
    init(confirmButtonTitle: String = "Submit", onSubmit: @escaping ([LLMMessage]) -> Void) {
        self.confirmButtonTitle = confirmButtonTitle
        self.onSubmit = onSubmit
        
        // Initialize messageModes for any existing messages
        _messageModes = State(initialValue: [:])
    }
    
    private func initializeNewMessageMode(_ id: UUID) {
        messageModes[id] = .edit
    }
    
    private func setEditMode(for messageId: UUID) {
        // Switch any existing edit modes to full mode
        for (id, mode) in messageModes {
            if mode == .edit {
                messageModes[id] = .full
            }
        }
        // Set the target message to edit mode
        messageModes[messageId] = .edit
    }
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                if state.messages.isEmpty {
                    Text("No messages")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }
                ForEach(state.messages) { message in
                    MessageRow(
                        message: Binding(
                            get: { message },
                            set: { newValue in
                                if let index = state.messages.firstIndex(where: { $0.id == message.id }) {
                                    state.messages[index] = newValue
                                }
                            }
                        ),
                        mode: Binding<MessageRowMode>(
                            get: { messageModes[message.id] ?? .compact },
                            set: { newMode in
                                if newMode == .edit {
                                    setEditMode(for: message.id)
                                } else {
                                    messageModes[message.id] = newMode
                                }
                            }
                        ),
                        confirmButtonTitle: confirmButtonTitle,
                        onConfirm: { handleConfirm(for: message) },
                        onCancel: { handleCancel(for: message) },
                        onCopy: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            
            HStack {
                Spacer()
                Button(confirmButtonTitle) {
                    finalizeAndSubmit()
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.messages.isEmpty || 
                         (messageModes.values.contains(.edit) && 
                          messageModes[state.messages.last?.id ?? UUID()] != .edit))
            }
            .padding()
        }
        .onChange(of: state.messages) { _, messages in
            withAnimation {
                cleanupMessageModes()
                checkAndAddNewMessage(messages)
            }
        }
        .onAppear {
            // Set initial message to edit mode if it's the only message
            if state.messages.count == 1 {
                initializeNewMessageMode(state.messages[0].id)
            }
        }
    }
    
    private func handleConfirm(for message: LLMMessage) {
        messageModes.removeValue(forKey: message.id)  // Remove mode entirely instead of setting to compact
    }
    
    private func handleCancel(for message: LLMMessage) {
        messageModes.removeValue(forKey: message.id)
    }
    
    private func cleanupMessageModes() {
        // Remove any mode entries for messages that no longer exist
        messageModes = messageModes.filter { messageId, _ in
            state.messages.contains { $0.id == messageId }
        }
    }
    
    private func finalizeAndSubmit() {
        // Remove any trailing empty messages
        var removedAny = false
        while let last = state.messages.last,
              last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if state.removeMessage(last.id) {
                removedAny = true
            }
        }
        
        cleanupMessageModes()
        
        if removedAny {
            withAnimation {
                onSubmit(state.messages)
            }
        } else {
            onSubmit(state.messages)
        }
    }
    
    private func checkAndAddNewMessage(_ messages: [LLMMessage]) {
        if messages.isEmpty {
            withAnimation(.spring()) {
                let newMessage = LLMMessage(role: .user, content: "")
                state.addMessage(newMessage)
                messageModes[newMessage.id] = .edit
            }
        } else if messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
            withAnimation(.spring()) {
                let newMessage = LLMMessage(role: .user, content: "")
                state.addMessage(newMessage)
                messageModes[newMessage.id] = .edit
            }
        }
    }
} 

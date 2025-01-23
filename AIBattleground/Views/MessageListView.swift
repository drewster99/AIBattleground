import SwiftUI

struct MessageListView: View {
    @EnvironmentObject private var state: MessageListState

    let confirmButtonTitle: String
    let onSubmit: ([LLMMessage]) -> Void

    init(confirmButtonTitle: String = "Submit", onSubmit: @escaping ([LLMMessage]) -> Void) {
        self.confirmButtonTitle = confirmButtonTitle
        self.onSubmit = onSubmit
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                if state.editingMessages.isEmpty {
                    Text("No messages")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                ForEach($state.editingMessages, id: \.self) { editingMessage in
                    MessageRow(
                        editingMessage: editingMessage,
                        confirmButtonTitle: confirmButtonTitle,
                        onConfirm: { handleConfirm(for: editingMessage) },
                        onCancel: { handleCancel(for: editingMessage) },
                        onDelete: { state.removeMessage(editingMessage.wrappedValue) },
                        onCopy: {
                            
                        },
                        onEditTapped: { }
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
                .disabled(state.editingMessages.isEmpty)
            }
            .padding()
        }
//        .onChange(of: state.editingMessages) { _, editingMessages in
//            withAnimation {
//                cleanupMessageModes()
////                checkAndAddNewMessage(editingMessages.messag)
//            }
//        }
//        .onAppear {
//            // Set initial message to edit mode if it's the only message
////            if state.messages.count == 1 {
////                initializeNewMessageMode(state.messages[0].id)
////            }
//        }
    }

    private func handleConfirm(for editingMessage: Binding<EditingMessageModel>) {
        print("confirm: ** wrapped \(editingMessage.wrappedValue.debugDescription)")
        state.endEditing(editingMessage.wrappedValue)
//        editingMessage.wrappedValue.rowMode = .compact
//        if state.editingMessages.last?.id == editingMessage.wrappedValue.id {
//                // append a new message
////            print("* appending new")
////            state.appendEmptyMessage()
//        } else {
//            if let lastIndex = state.editingMessages.indices.last {
//                state.editingMessages[lastIndex].rowMode = .edit
//                state.focusedMessageID = state.editingMessages[lastIndex].id
//            }
//        }
//        if message.id != state.messages.last?.id {
//            messageModes.removeValue(forKey: message.id)
//        }
    }

    private func handleCancel(for editingMessage: Binding<EditingMessageModel>) {
        print("cancel: \(editingMessage)")
        if let lastMessage = state.editingMessages.last {
            state.beginEditing(lastMessage)
        }
//        if message.id != state.messages.last?.id {
//            messageModes.removeValue(forKey: message.id)
//        }
    }

    private func cleanupMessageModes() {
        print("clean up messages modes")
//        let lastId = state.editingMessages.last?.id
//        messageModes = messageModes.filter { messageId, _ in
//            let exists = state.editingMessages.contains { $0.id == messageId }
//            if exists && messageId == lastId {
//                // Ensure last message mode is correct
//                setEditMode(for: lastId!)
//            }
//            return exists
//        }
    }

    private func finalizeAndSubmit() {
        print("finalize and submit")
        // Remove any trailing empty messages
        while let last = state.editingMessages.last?.message,
              last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.editingMessages.removeAll(where: { $0.id == last.id })
        }

        cleanupMessageModes()

        withAnimation {
            onSubmit(state.editingMessages.map(\.message))
        }
    }

    private func checkAndAddNewMessage(_ messages: [LLMMessage]) {
//        if messages.isEmpty {
//            withAnimation(.spring()) {
//                let newMessage = LLMMessage(role: .user, content: "")
//                state.addMessage(newMessage)
//                setEditMode(for: newMessage.id)
//            }
//        } else if messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) != "" {
//            withAnimation(.spring()) {
//                let newMessage = LLMMessage(role: .user, content: "")
//                state.addMessage(newMessage)
//                setEditMode(for: newMessage.id)
//            }
//        }
    }
}

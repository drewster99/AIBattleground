import SwiftUI

struct MessageListEditView: View {
    @Binding public var editingMessages: [EditingMessageModel]
    @State private var idOfMessageBeingEdited: EditingMessageModel.ID?
    @Namespace private var animation
    
    public let onSubmit: ([LLMMessage]) -> Void
    
    var body: some View {
        VStack {
            if editingMessages.isEmpty {
                Text("No messages")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .listRowBackground(Color.clear)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading) {
                        ForEach($editingMessages) { editingMessage in
                            MessageRow(
                                editingMessage: editingMessage,
                                idOfMessageBeingEdited: idOfMessageBeingEdited,
                                onConfirm: {
                                    let messageID = editingMessage.wrappedValue.id
                                    let finalMessageID = editingMessages.last?.id
                                    let isBeingEdited = idOfMessageBeingEdited == messageID
                                    let isFinalMessage = messageID == finalMessageID
                                    print("onConfirm: ** wrapped \(editingMessage.wrappedValue.debugDescription) isBeingEdited=\(isBeingEdited), isFinalMessage=\(isFinalMessage) **")
                                    if isFinalMessage {
                                        if !editingMessage.wrappedValue.message.content.isEmpty {
                                            let newMessage = EditingMessageModel.empty()
                                            let id = newMessage.id
                                            editingMessages.append(newMessage)
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                                idOfMessageBeingEdited = id
                                            }
                                        }
                                    } else {
                                        idOfMessageBeingEdited = nil
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            idOfMessageBeingEdited = finalMessageID
                                        }
                                    }
                                },
                                onCancel: {
                                    print("onCancel: \(editingMessage.wrappedValue.debugDescription)")
                                    let messageID = editingMessage.wrappedValue.id
                                    let finalMessageID = editingMessages.last?.id
                                    let isBeingEdited = idOfMessageBeingEdited == messageID
                                    let isFinalMessage = messageID == finalMessageID
                                    print("onCancel: ** wrapped \(editingMessage.wrappedValue.debugDescription) isBeingEdited=\(isBeingEdited), isFinalMessage=\(isFinalMessage) **")
                                    if isFinalMessage {
                                        if !editingMessage.wrappedValue.message.content.isEmpty {
                                            addNewMessage()
                                        }
                                    } else {
                                        idOfMessageBeingEdited = finalMessageID
                                    }
                                },
                                onDelete: {
                                    print("onDelete: \(editingMessage.wrappedValue.debugDescription)")
                                },
                                onCopy: {
                                    print("onCopy: \(editingMessage.wrappedValue.debugDescription)")
                                },
                                onEditRequested: {
                                    print("onEditRequested")
                                },
                                onExpandRequested: {
                                    print("onExpandRequested")
                                },
                                onEditingBegan: {
                                    print("onEditingBegan for \(editingMessage.wrappedValue.debugDescription)")
                                    idOfMessageBeingEdited = editingMessage.wrappedValue.id
                                }
                            )
                        }
                    }
                }
            }
            Button(action: {
                
                addNewMessage()
            }, label: {
                Label("Add Message", systemImage: "plus.bubble.fill")
            })
            .padding()
        }
        .onAppear {
            if editingMessages.isEmpty {
                addNewMessage()
            }
            if let finalIndex = editingMessages.indices.last {
                idOfMessageBeingEdited = editingMessages[finalIndex].id
            }
        }
    }
    
    private func addNewMessage() {
        print("Add new message")
        if idOfMessageBeingEdited != nil {
            self.idOfMessageBeingEdited = nil
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let newMessage = EditingMessageModel.empty()
            let id = newMessage.id
            editingMessages.append(newMessage)
            idOfMessageBeingEdited = id
        }
    }
}

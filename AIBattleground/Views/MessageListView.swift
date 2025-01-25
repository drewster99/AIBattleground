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
            // Note to self:
            //   If you use List directly, like this:
            //     List($state.editingMessages, id: \.id) { editingMessage in ...
            //   Each closure is just given the editingMessage structs -- not bindings, interestingly
            List {
                if state.editingMessages.isEmpty {
                    Text("No messages")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowBackground(Color.clear)
                }

                // Note to self:
                //   When this line below looked like this:
                //     ForEach($state.editingMessages, id: \.self) { ...
                //   When things changed, all MessageRows would get re-created,
                //   firing their .onAppear, rather than their .onChange.
                ForEach($state.editingMessages) { editingMessage in
                    MessageRow(
                        editingMessage: editingMessage,
                        confirmButtonTitle: confirmButtonTitle,
                        onConfirm: {
                            print("confirm: ** wrapped \(editingMessage.wrappedValue.debugDescription)")
                            let isEmpty = editingMessage.wrappedValue.message.content.isEmpty
                            let isLastMessage = state.editingMessages.last?.id == editingMessage.wrappedValue.id

                            if !isLastMessage || (isLastMessage && !isEmpty) {
                                editingMessage.projectedValue.wrappedValue.rowMode = .compact
                            } else {
                                onSubmit(state.editingMessages.map(\.message))
                            }
                        },
                        onCancel: {
                            print("cancel: \(editingMessage)")
                            if let lastMessage = state.editingMessages.last, editingMessage.id == lastMessage.id {
                                // leave it editing
                            } else {
                                // collapse
                                editingMessage.projectedValue.wrappedValue.rowMode = .compact
                            }
                        },
                        onDelete: {
//                            state.removeMessage(editingMessage.wrappedValue)
                        },
                        onCopy: {
                            
                        },
                        onEditRequested: {
                            state.beginEditing(editingMessage.wrappedValue.id)
                        },
                        onExpandRequested: {
                            editingMessage.wrappedValue.rowMode = .full
                        },
                        onEditingBegan: {
                            // this is really sort of an "onEditingBegan"
                            print("Editing began for \(editingMessage.wrappedValue.debugDescription)")
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
                .disabled(state.editingMessages.isEmpty)
            }
            .padding()
        }
    }

    private func finalizeAndSubmit() {
        print("finalize and submit")
        // Remove any trailing empty messages
        while let last = state.editingMessages.last?.message,
              last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            state.editingMessages.removeAll(where: { $0.id == last.id })
        }

        withAnimation {
            onSubmit(state.editingMessages.map(\.message))
        }
    }
}

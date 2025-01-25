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
        ScrollView {
            VStack(spacing: 0) {
                // Note to self -- using List seems to ruin lives and cause weird blinky animations,
                // presumably from something getting reinitialized.
                // Note to self:
                //   If you use List directly, like this:
                //     List($state.editingMessages, id: \.id) { editingMessage in ...
                //   Each closure is just given the editingMessage structs -- not bindings, interestingly
                //            List {
//                if state.editingMessages.isEmpty {
//                    Text("No messages")
//                        .foregroundStyle(.secondary)
//                        .frame(maxWidth: .infinity, alignment: .center)
//                        .listRowBackground(Color.clear)
//                }

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
                            print("onConfirm: ** wrapped \(editingMessage.wrappedValue.debugDescription)")
//                            withAnimation {
//                                editingMessage.wrappedValue.rowDisplayStyle = .compact
//                            }
//                            let isEmpty = editingMessage.wrappedValue.message.content.isEmpty
//                            let isLastMessage = state.editingMessages.last?.id == editingMessage.wrappedValue.id
//
//                            if !isLastMessage || (isLastMessage && !isEmpty) {
//                                withAnimation {
//                                    editingMessage.rowMode.wrappedValue = .compact
//                                }
//                            } else {
//                                onSubmit(state.editingMessages.map(\.message))
//                            }
                        },
                        onCancel: {
                            print("onCancel: \(editingMessage)")
//                            if let lastMessage = state.editingMessages.last, editingMessage.id == lastMessage.id {
//                                // leave it editing
//                            } else {
//                                // collapse
////                                withAnimation {
////                                    editingMessage.rowMode.wrappedValue = .compact
////                                }
//                                // In this form, everything blinks and jumps as if just being added to the view.
//                                // That's dumb.
//                                // withAnimation {
//                                //     editingMessage.projectedValue.wrappedValue.rowMode = .compact
//                                // }
//
//                                // In this form, nothing blinky happens, but animation doesn't happen either
//                                //                                 withAnimation {
//                                //                                     editingMessage.rowMode.wrappedValue = .compact
//                                //                                 }
//                            }
                        },
                        onDelete: {
                            //                            state.removeMessage(editingMessage.wrappedValue)
                        },
                        onCopy: {

                        },
                        onEditRequested: {
                            print("onEditRequested")
//                            withAnimation {
//                                editingMessage.wrappedValue.rowDisplayStyle = .edit
//                            }
                            // This still causes blinkage.  Why?  The one above in the onCancel does not.
//                            withAnimation {
//                                editingMessage.rowMode.wrappedValue = .edit
                                //                                state.beginEditing(editingMessage.wrappedValue.id)
//                            }
                            // This form causes blinky garbage - presumably because we're taking
                            // the wrappedValue of editingMessage, causing the entire thing to be
                            // changed?
                            // withAnimation {
                            //     editingMessage.wrappedValue.rowMode = .edit
                            //                          //       state.beginEditing(editingMessage.wrappedValue.id)
                            // }
                        },
                        onExpandRequested: {
                            print("onExpandRequested")
//                            withAnimation {
//                                editingMessage.wrappedValue.rowDisplayStyle = .full
//                            }
//                            withAnimation {
//                                editingMessage.rowMode.wrappedValue = .full
//                            }
                        },
                        onEditingBegan: {
                            print("onEditingBegan for \(editingMessage.wrappedValue.debugDescription)")
//                            print("onEditingBegan")
                        }
                    )
                    // .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
//                    .listRowSeparator(.hidden)
                }
                //            }
                //            .listStyle(.plain)


//                HStack {
//                    Spacer()
//                    Button(confirmButtonTitle) {
//                        finalizeAndSubmit()
//                    }
//                    .buttonStyle(.borderedProminent)
//                    .disabled(state.editingMessages.isEmpty)
//                }
//                .padding()
            }
        }
    }

    private func finalizeAndSubmit() {
        print("finalize and submit")
        withAnimation {
            // Remove any trailing empty messages
            while let last = state.editingMessages.last?.message,
                  last.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                state.editingMessages.removeAll(where: { $0.id == last.id })
            }

            onSubmit(state.editingMessages.map(\.message))
        }
    }
}

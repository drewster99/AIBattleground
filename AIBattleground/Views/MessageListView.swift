import SwiftUI

struct MessageListView: View {
    @Binding public var editingMessages: [EditingMessageModel] 
    @Namespace private var animation

    public let confirmButtonTitle: String
    public let onSubmit: ([LLMMessage]) -> Void

    var body: some View {

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
                            confirmButtonTitle: confirmButtonTitle,
                            onConfirm: {
                                print("onConfirm: ** wrapped \(editingMessage.wrappedValue.debugDescription)")
                            },
                            onCancel: {
                                print("onCancel: \(editingMessage.wrappedValue.debugDescription)")
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
                            }
                        )
                    }
                    HStack {
                        Spacer()
                        Button(confirmButtonTitle) {
                            editingMessages.append(.empty())
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [.command, .option])
                    }
                    .padding()
                }
            }
        }
    }
}

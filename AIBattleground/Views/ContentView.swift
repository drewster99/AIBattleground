import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var credentialManager: LLMCredentialKeyManager
    @State private var selectedTab: Tab? = .services

    private enum Tab {
        case debugServices
        case debugMessages
        case debugSingleMessage
        case services
        case models
        case challenge
    }

    var body: some View {
        NavigationView {
            List(selection: $selectedTab) {
                Group {
#if DEBUG
                    NavigationLink {
                        DebugServicesView()
                    } label: {
                        Label("Debug Services", systemImage: "ladybug.fill")
                            .padding()
                    }
                    .tag(Tab.debugServices)
                    NavigationLink {
                        DebugMessageListView()
                    } label: {
                        Label("Debug Messages", systemImage: "message.fill")
                            .padding()
                    }
                    .tag(Tab.debugMessages)
                    NavigationLink {
                        DebugSingleMessageView()
                    } label: {
                        Label("Debug Single Message", systemImage: "message.fill")
                            .padding()
                    }
                    .tag(Tab.debugSingleMessage)
#endif

                    NavigationLink {
                        ManageServicesView()
                    } label: {
                        Label("Services", systemImage: "key.fill")
                            .padding()
                    }
                    .tag(Tab.services)

                    NavigationLink {
                        ManageModelsView()
                    } label: {
                        Label("Models", systemImage: "cpu.fill")
                            .padding()
                    }
                    .tag(Tab.models)

                    NavigationLink {
                        ChallengeView()
                    } label: {
                        Label("Challenge", systemImage: "trophy.fill")
                            .padding()
                    }
                    .tag(Tab.challenge)
                }
            }
            .font(.title3)
            .frame(minWidth: 200)
            .listStyle(.sidebar)
            .navigationTitle("AI Battleground")
        }
    }
}

struct DebugMessageListView: View {
    @StateObject private var rolesManager = CustomRolesManager()
    @StateObject private var messageListState = MessageListState([], isEditable: true)

    var body: some View {
        MessageListView(
            confirmButtonTitle: "Send to AI",
            onSubmit: { messages in
                print("messages: \(messages)")
            }
        )
        .environmentObject(messageListState)
        .environmentObject(rolesManager)
    }
}

struct DebugSingleMessageView: View {
    @StateObject private var rolesManager = CustomRolesManager()
    @State private var editingMessage = EditingMessageModel(rowMode: .edit, isEditable: true, message: LLMMessage.empty())
    @State private var lastCallback: String = ""

    var rowMode: MessageRowMode {
        get { editingMessage.rowMode }
        nonmutating set { editingMessage.rowMode = newValue }
    }
    var body: some View {
        VStack {
            MessageRow(editingMessage: $editingMessage,
                       confirmButtonTitle: "Confirm") {
                // onConfirm
                lastCallback = "onConfirm"
            } onCancel: {
                lastCallback = "onCancel"
            } onDelete: {
                lastCallback = "onDelete"
            } onCopy: {
                lastCallback = "onCopy"
            } onEditRequested: {
                lastCallback = "onEditRequested"
                rowMode = .edit
            } onExpandRequested: {
                lastCallback = "onExpandRequested"
                rowMode = .full
            } onEditingBegan: {
                lastCallback = "onEditingBegan"
            }
            .environmentObject(rolesManager)
            Spacer()
            

            Text("Last callback: \(lastCallback)")
            Text("Message: \(editingMessage.message.content)")
                .background(.secondary)
                .frame(minHeight: 100)
                .frame(maxWidth: .infinity)
                .padding()
            Button("editing is: \(editingMessage.isEditable ? "ENABLED" : "DISABLED")") {
                editingMessage.isEditable.toggle()
            }
            HStack {
                Button("Edit") {
                    rowMode = .edit
                }
                Button("Full") {
                    rowMode = .full
                }
                Button("Compact") {
                    rowMode = .compact
                }
            }
        }
    }
}

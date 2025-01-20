import Foundation
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var credentialManager: LLMCredentialKeyManager
    @State private var selectedTab: Tab? = .services
    @StateObject private var messageListState = MessageListState(messages: [], isEditable: true)

    private enum Tab {
        case debug
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
                        .tag(Tab.debug)
                        NavigationLink {
                            MessageListView(
                                confirmButtonTitle: "Send to AI",
                                onSubmit: { messages in
                                    print("messages: \(messages)")
                                }
                            )
                            .environmentObject(messageListState)
                        } label: {
                            Label("Debug Messages", systemImage: "message.fill")
                                .padding()
                        }
                        .tag(Tab.debug)
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

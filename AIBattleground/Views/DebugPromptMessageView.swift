import SwiftUI

struct DebugPromptMessageView: View {
    @StateObject private var rolesManager = CustomRolesManager()
    @State private var message = PromptMessage(
        id: UUID(),
        role: .system,
        text: "You are a helpful assistant.",
        variableReplacements: []
    )
    
    var body: some View {
        VStack {
            PromptMessageEditView(message: $message)
            Divider()
            Text("Debug Info:")
                .font(.headline)
            Text("Text: \(message.text)")
            Text("Variables: \(message.variableReplacements.count)")
            ForEach(message.variableReplacements) { replacement in
                Text("Variable '\(replacement.variable.name)' at position \(replacement.insertionPoint)")
            }
        }
        .padding()
        .environmentObject(rolesManager)
    }
} 
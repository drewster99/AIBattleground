import SwiftUI
import AppKit

struct PromptMessageEditView: View {
    @Binding var message: PromptMessage
    @State private var text: String
    @State private var showingVariableMenu = false
    @State private var insertionPoint: Int?
    @StateObject private var textStorage = VariableTextStorage()
    
    init(message: Binding<PromptMessage>) {
        self._message = message
        self._text = State(initialValue: message.wrappedValue.text)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoleSelector(role: $message.role)
            
            VariableTextView(
                text: $text,
                storage: textStorage,
                onInsertVariable: {
                    if let textView = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
                        insertionPoint = textView.selectedRange().location
                        showingVariableMenu = true
                    }
                }
            )
            .frame(minHeight: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
            .focusable()
        }
        .padding()
        .onAppear {
            // Set up the storage update handler
            textStorage.setVariableUpdateHandler { replacements in
                message.variableReplacements = replacements
            }
            
            // Insert any existing variables after a brief delay to ensure the text view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                for replacement in message.variableReplacements {
                    textStorage.insertVariable(replacement.variable, at: replacement.insertionPoint)
                }
            }
        }
        .popover(isPresented: $showingVariableMenu) {
            VariableInsertMenu(
                storage: textStorage,
                insertionPoint: insertionPoint,
                variableReplacements: $message.variableReplacements
            )
            .frame(width: 300)
            .padding()
        }
        .onChange(of: text) {
            message.text = text
        }
    }
}

struct VariableInsertMenu: View {
    let storage: VariableTextStorage
    let insertionPoint: Int?
    @Binding var variableReplacements: [VariableReplacement]
    @State private var newVariableName = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Insert Variable")
                .font(.headline)
            
            if let point = insertionPoint {
                Text("Will insert at position: \(point)")
                    .font(.caption)
            } else {
                Text("No insertion point selected")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            TextField("New Variable Name", text: $newVariableName)
                .textFieldStyle(.roundedBorder)
            
            Button("Create & Insert") {
                guard !newVariableName.isEmpty, let insertPoint = insertionPoint else {
                    print("Cannot insert: empty=\(!newVariableName.isEmpty) point=\(String(describing: insertionPoint))")
                    return
                }
                
                print("Creating variable at position \(insertPoint)")
                
                // Create new variable
                let variable = PromptVariable(
                    id: UUID(),
                    name: newVariableName,
                    description: nil,
                    variableType: .string
                )
                
                // Insert the variable using storage
                storage.insertVariable(variable, at: insertPoint)
                dismiss()
            }
            .disabled(newVariableName.isEmpty)
            .buttonStyle(.borderedProminent)
        }
    }
} 
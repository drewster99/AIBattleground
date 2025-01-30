import Foundation
import SwiftUI
import AppKit

struct PromptMessageEditView: View {
    @Binding public var message: PromptMessage
    @State private var text: String = ""
    @State private var showingVariableMenu = false
    @State private var insertionPoint: Int?
    @StateObject private var textStorage = VariableTextStorage()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoleSelector(role: $message.role)

            VariableTextView(
                text: $text,
                storage: textStorage,
                onInsertVariable: {
                    if let textView = NSApplication.shared.keyWindow?.firstResponder as? NSTextView {
                        let otherPoint = textView.selectedRanges.compactMap { $0.rangeValue }.first?.location
                        let otherPoint2 = textView.selectedRanges.first?.rangeValue.location
                        // this will trigger popover
                        insertionPoint = otherPoint
                    }
                }
            )
            .focusable()
            .frame(minHeight: 100)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
        }
        .padding()
        .onAppear {
            print("PromptMessageEditView *** onAppear")
            text = message.text

            // Set up the storage update handler
            textStorage.setVariableUpdateHandler { replacements in
                Task { @MainActor in message.variableReplacements = replacements }
            }

            for replacement in message.variableReplacements {
                textStorage.insertVariable(replacement.variable, at: replacement.insertionPoint, viewText: $text)
            }
        }
        .popover(isPresented: $showingVariableMenu) {
            VariableInsertMenu(
                storage: textStorage,
                insertionPoint: insertionPoint,
                variableReplacements: $message.variableReplacements,
                viewText: $text
            )
            .frame(width: 300)
            .padding()
        }
        .onChange(of: insertionPoint) {
            if insertionPoint != nil {
                showingVariableMenu = true
            }
        }
        .onChange(of: showingVariableMenu) {
            if !showingVariableMenu {
                insertionPoint = nil
            }
        }
        .onChange(of: text) {
            message.text = text
        }
    }
}

struct VariableInsertMenu: View {
    public init(storage: VariableTextStorage, insertionPoint: Int? = nil, variableReplacements: Binding<[VariableReplacement]>, viewText: Binding<String>) {
        print("*** VartiableInsertMenu: init() ***")
        self.storage = storage
        self.insertionPoint = insertionPoint
        self._variableReplacements = variableReplacements
        self._viewText = viewText
    }
    
    let storage: VariableTextStorage
    let insertionPoint: Int?
    @Binding var variableReplacements: [VariableReplacement]
    @State private var newVariableName = ""
    @Environment(\.dismiss) private var dismiss
    @Binding var viewText: String

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
                storage.insertVariable(variable, at: insertPoint, viewText: $viewText)
                dismiss()
            }
            .disabled(newVariableName.isEmpty)
            .buttonStyle(.borderedProminent)
        }
        .onAppear {
            print("VariableInsertMenu: insertionPoint = \(insertionPoint)")
        }
    }
}


// I have some Swift code.  The PromptMessageEditView is supposed to display a text box where the user can type text - this part works.  But they are supposed to be able to hit Command-4 and enter a placeholder for a variable.  When they hit command-4, they get prompted to enter a variable name -- so that part is good.  AND it says that there is 1 variable defined.  That's good too.  However, I don't ever see the variable placeholder in the text view, and as soon as I start to type anything else in the view, the 1 defined variable disappears.  Do you think you can fix this?  Here is the code:

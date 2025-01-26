import SwiftUI

enum MessageDisplayStyle: String, Codable, Equatable, Hashable, Identifiable {
    /// brief summary
    case compact

    /// fully expanded
    case full

    /// fully expanded and edting
    case edit

    var id: String { rawValue }
}

struct MessageRow: View {
    @EnvironmentObject private var rolesManager: CustomRolesManager
    @Binding var editingMessage: EditingMessageModel
    let idOfMessageBeingEdited: EditingMessageModel.ID?
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onEditRequested: () -> Void
    let onExpandRequested: () -> Void
    let onEditingBegan: () -> Void

    @State private var displayStyle: MessageDisplayStyle = .compact
    @State private var isEditing: Bool = false
    @State private var editingText: String = ""
    @State private var showingCopyConfirmation = false
    @State private var copyConfirmationTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool
    @Namespace private var animation
    @State private var originalRole: LLMMessage.MessageRole?

    var isEditable: Bool { editingMessage.isEditable }
    var contentHasChanged: Bool { editingText != editingMessage.message.content || originalRole != editingMessage.message.role }

    private var compactText: String {
        editingMessage.message.content
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\n", with: "  ↵  ")
    }

    private func formatMessage(_ text: String) -> AttributedString {
        do {
            let options = AttributedString.MarkdownParsingOptions(allowsExtendedAttributes: true,
                                                                  interpretedSyntax: .inlineOnly,
                                                                  failurePolicy: .returnPartiallyParsedIfPossible,
                                                                  languageCode: nil,
                                                                  appliesSourcePositionAttributes: true)

            var attributed = try AttributedString(markdown: text, options: options)
            if case .other = editingMessage.message.role {
                attributed.foregroundColor = .secondary
            }
            return attributed
        } catch {
            return AttributedString(text)
        }
    }

    private func handleEditRequest() {
        guard isEditable else { return }
        guard !isEditing else { return }
        print(">> handleEditRequest")
        withAnimation {
            isEditing = true
            onEditRequested()
        }
    }

    private func handleExpandRequest() {
        guard !isEditing else { return }
        guard displayStyle != .full else { return }
        print(">> handleExpandRequest")
        withAnimation {
            displayStyle = .full
            onExpandRequested()
        }
    }

    private func handleCancel() {
        guard isEditing else { return }
        print(">> handleCancel")
        withAnimation {
            editingText = editingMessage.message.content
            if let originalRole, originalRole != editingMessage.message.role {
                editingMessage.message.role = originalRole
            }
            //            isTextFieldFocused = false
            isEditing = false
            onCancel()
        }
    }

    private func handleConfirm() {
        guard isEditing else { return }
        print(">> handleConfirm")
        withAnimation {
            let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
            if editingMessage.message.content != trimmedText {
                editingMessage.message.content = trimmedText
                editingText = trimmedText
            }
            originalRole = editingMessage.message.role
            isTextFieldFocused = false
            isEditing = false
            onConfirm()
        }
    }

    /// Displays the message role and allows user to change it
    var roleSelector: some View {
        RoleSelector(
            role: $editingMessage.message.role
        )
        .opacity(isEditable && displayStyle == .edit ? 1.0 : 0.7)
        .disabled(!(isEditable && displayStyle == .edit))
    }

    /// A button which copies the main content text to the clipboard
    var copyButton: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            let copiedContent = displayStyle == .compact ? editingMessage.message.content : editingText
            print("* Copy: \"\(copiedContent)\"")
            NSPasteboard.general.setString(copiedContent, forType: .string)

            onCopy()
            showingCopyConfirmation = true

            // Cancel any existing task
            copyConfirmationTask?.cancel()

            // Create new task
            copyConfirmationTask = Task {
                try? await Task.sleep(for: .seconds(2))
                if !Task.isCancelled {
                    await MainActor.run {
                        showingCopyConfirmation = false
                    }
                }
            }
        }) {
            if showingCopyConfirmation {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
                    .accessibilityLabel("Copied")
            } else {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Copy message")
            }
        }
        .frame(width: 44, height: 44)
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    /// A pencil button that can be used to begin editing
    var editButton: some View {
        Button(action: {
            handleEditRequest()
        }, label: {
            Image(systemName: "pencil")
                .foregroundStyle(.secondary)
                .opacity(editingMessage.isEditable ? 1.0 : 0.7)
        })
        .buttonStyle(.plain)
        .accessibilityLabel("Edit message")
        .disabled(!editingMessage.isEditable)
    }

    var bottomTools: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                handleCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Cancel editing")

            Button("Save") {
                print("doing confirm on \(editingMessage.debugDescription)... editingtext = \(editingText)")
                handleConfirm()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityLabel("Confirm changes")
            .opacity(contentHasChanged ? 1.0 : 0.7)
            .disabled(!contentHasChanged)
        }
    }

    /// Compact 1-liner view
    var compactView: some View {
        HStack(spacing: 4) {
            Text(compactText)
                .lineLimit(1)
                .truncationMode(.tail)

            if compactText.count > 100 {  // Show (more) if multiline or long
                Text("(more)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityLabel("Message preview")
        .accessibilityHint("Tap to \(isEditable ? "edit" : "expand")")
        .onTapGesture {
            if isEditable {
                handleEditRequest()
            } else {
                handleExpandRequest()
            }
        }
    }

    var fullContentView: some View {
        ScrollView(.vertical) {
            HStack {
                Text(formatMessage(editingText))
                //                Text(editingText)
                    .multilineTextAlignment(.leading)
                    .font(.body)
                    .frame(minHeight: 100)
                //                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: .infinity)
                    .frame(alignment: .leading)
                //                    .layoutPriority(1)
                    .padding(.top, 2)
                    .padding(.horizontal, 4)

                Spacer()
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
            .accessibilityLabel("Message content")
        }
        .overlay {
            // Add a hidden button to handle option-r
            Button("Next role") {
                if editingMessage.isEditable {
                    editingMessage.message.role = rolesManager.nextRole(after: editingMessage.message.role)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut("r", modifiers: [.command])
            .hidden()
        }
    }

    /// Fully expanded editable text
    var editView: some View {
        TextEditor(text: $editingText)
            .font(.body)
            .frame(minHeight: 100)
            .focusable()
            .focused($isTextFieldFocused)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2))
            )
            .accessibilityLabel("Message content")
            .accessibilityHint("Enter your message")
            .onSubmit {
                print("onSubmit .. $editText = \(self.editingText)")
            }
            .overlay {
                // Add a hidden button to handle option-r
                Button("Next role") {
                    if editingMessage.isEditable {
                        editingMessage.message.role = rolesManager.nextRole(after: editingMessage.message.role)
                    }
                }
                .buttonStyle(.plain)
                .keyboardShortcut("r", modifiers: [.command])
                .hidden()
            }
    }

    func updateDisplayStyleAfterEditing() {
        var newStyle: MessageDisplayStyle = displayStyle
        switch isEditable {
        case true:
            // we are now editable (and weren't before)
            newStyle = editingMessage.preferredDisplayStyle

        case false:
            // we are not editable
            if isEditing {
                if contentHasChanged {
                    handleConfirm()
                } else {
                    handleCancel()
                }

                if editingMessage.preferredDisplayStyle == .compact {
                    newStyle = .compact
                } else {
                    newStyle = .full
                }
            } else {
                if editingMessage.preferredDisplayStyle != .edit {
                    newStyle = editingMessage.preferredDisplayStyle
                }
            }
        }

        if newStyle != displayStyle {
            print("updateDisplayStyleAfterEditing (isEditing=\(isEditing), isEditable=\(isEditable), preferred=\(editingMessage.preferredDisplayStyle):  \(displayStyle) -> \(newStyle)")
            withAnimation {
                displayStyle = newStyle
            }
        } else {
            print("updatedDisplayStyleAfterEditing (isEditing=\(isEditing), isEditable=\(isEditable), preferred=\(editingMessage.preferredDisplayStyle): unchanged \(displayStyle)")
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            if displayStyle == .compact {
                HStack(alignment: .top) {
                    roleSelector
                        .matchedGeometryEffect(id: "RoleSelector", in: animation)
                    compactView
                        .matchedGeometryEffect(id: "Content", in: animation, anchor: UnitPoint.topLeading)
                    editButton
                        .matchedGeometryEffect(id: "EditButton", in: animation)
                }
                .matchedGeometryEffect(id: "Container", in: animation, anchor: .topLeading)
            } else if displayStyle == .edit || displayStyle == .full {
                //                VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    roleSelector
                        .matchedGeometryEffect(id: "RoleSelector", in: animation)
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottomTrailing) {
                            if displayStyle == .edit {
                                editView
                                    .opacity(displayStyle == .full || isEditable == false ? 0.7 : 1.0)
                                    .disabled(displayStyle == .full || isEditable == false)
                                    .matchedGeometryEffect(id: "Content", in: animation, anchor: UnitPoint.topLeading)
                            } else {
                                fullContentView
                                    .matchedGeometryEffect(id: "Content", in: animation, anchor: UnitPoint.topLeading)
                            }
                            copyButton
                        }
                        bottomTools
                            .opacity(displayStyle == .full || isEditable == false ? 0.0 : 1.0)
                    }
                    editButton
                        .opacity(displayStyle == .full ? 1.0 : 0.0)
                        .matchedGeometryEffect(id: "EditButton", in: animation)
                }
                //                }
                //                .matchedGeometryEffect(id: "Container", in: animation, anchor: .topLeading)
            } else {
                // unknown - future mode
                fatalError(">>> Unknown displayStyle \(displayStyle)")
            }
        }
        .padding(.horizontal)
        .animation(.easeInOut, value: displayStyle)
        .transition(.move(edge: .top))
        .onChange(of: isEditing) {
            switch isEditing {
            case true:
                withAnimation {
                    displayStyle = .edit
                }
                Task { @MainActor in isTextFieldFocused = true }
                onEditingBegan()
            case false:
                isTextFieldFocused = false
                updateDisplayStyleAfterEditing()
            }
        }
        .onChange(of: editingMessage.preferredDisplayStyle) { old, new in
            print("@@@ onChange of message \(editingMessage.message) preferredDisplayStyle:  \(old) --> \(new)")
            if displayStyle == old {
                displayStyle = new
            }
        }
        .onChange(of: editingMessage.message) {
            print("@@@ onChange of message \(editingMessage.message) originalRole: \(originalRole?.rawValue)")
        }
        .onChange(of: isEditable) { old, new in
            print("@@@ onChange \(editingMessage.debugDescription) isEditable \(old) --> \(new)")
        }
        .onChange(of: isEditable, initial: false) {
            print("@@@ onChange \(editingMessage.debugDescription) isEditable --> \(isEditable)")
            updateDisplayStyleAfterEditing()
        }
        .onChange(of: displayStyle) { old, new in
            print("@@@ onChange \(editingMessage.debugDescription) displayStyle \(old) --> \(new)")
        }
        .onChange(of: idOfMessageBeingEdited, initial: true) {
            print("@@@ onChange \(editingMessage.debugDescription) idOfMessageBeingEdited -----> \(idOfMessageBeingEdited)")
            if idOfMessageBeingEdited == editingMessage.id {
                // we need to start editing
                isEditing = true
            } else {
                isEditing = false
            }
        }
        .onAppear {
            print("@@ onAppear \(editingMessage.debugDescription)")
            editingText = editingMessage.message.content
            originalRole = editingMessage.message.role
        }
        .onDisappear {
            copyConfirmationTask?.cancel()
        }
    }
}

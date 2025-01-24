import SwiftUI

enum MessageRowMode: String, Codable, Equatable, Hashable, Identifiable {
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
    let confirmButtonTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void
    let onCopy: () -> Void
    let onEditRequested: () -> Void
    let onExpandRequested: () -> Void
    let onEditingBegan: () -> Void

    @State private var editingText: String = ""
    @State private var showingCopyConfirmation = false
    @State private var copyConfirmationTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool
    @Namespace private var animation
    @State private var originalRole: LLMMessage.MessageRole?

    var isEditable: Bool { editingMessage.isEditable }
    var rowMode: MessageRowMode { $editingMessage.rowMode.wrappedValue }
    var contentHasChanged: Bool { editingText != editingMessage.message.content || originalRole != editingMessage.message.role }

    private func formatMessage(_ text: String) -> AttributedString {
        do {
            let options = AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
            var attributed = try AttributedString(markdown: text, options: options)
            if case .other = editingMessage.message.role {
                attributed.foregroundColor = .secondary
            }
            return attributed
        } catch {
            return AttributedString(text)
        }
    }

    private func handleConfirm() {
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        editingMessage.message.content = trimmedText
        originalRole = editingMessage.message.role
        Task { @MainActor in onConfirm() }
    }

    private func setRowMode(_ rowMode: MessageRowMode) {
        var effectiveRowMode = rowMode
        if rowMode == .edit && !isEditable {
            effectiveRowMode = .full
        }
        if editingMessage.rowMode != effectiveRowMode {
            withAnimation {
                editingMessage.rowMode = effectiveRowMode
            }
        }
    }

    /// Displays the message role and allows user to change it
    var roleSelector: some View {
        RoleSelector(
            role: $editingMessage.message.role
        )
        .opacity(editingMessage.rowMode == .edit ? 1.0 : 0.7)
        .disabled(editingMessage.rowMode != .edit)
    }

    /// A button which copies the main content text to the clipboard
    var copyButton: some View {
        Button(action: {
            NSPasteboard.general.clearContents()
            let copiedContent = rowMode == .compact ? editingMessage.message.content : editingText
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
            if isEditable {
                onEditRequested()
            } else {
                onExpandRequested()
            }
        }, label: {
            Image(systemName: "pencil")
                .foregroundStyle(.secondary)
                .opacity(editingMessage.isEditable ? 1.0 : 0.7)
        })
        .buttonStyle(.plain)
        .disabled(!editingMessage.isEditable)
    }

    var trailingTools : some View {
        VStack {
            if editingMessage.rowMode != .edit {
                Button(action: {
                    if isEditable {
                        onEditRequested()
                    } else {
                        onExpandRequested()
                    }
                }, label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.secondary)
                        .opacity(editingMessage.isEditable ? 1.0 : 0.7)
                })
                .buttonStyle(.plain)
                .disabled(!editingMessage.isEditable)
            }
            Spacer()
            copyButton
        }
    }

    var bottomTools: some View {
        HStack {
            Spacer()
            Button("Cancel") {
                editingText = editingMessage.message.content
                originalRole = editingMessage.message.role
                onCancel()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Cancel editing")
            .opacity(contentHasChanged ? 0.7 : 1.0)
            .disabled(!contentHasChanged)

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
            Text(editingMessage.message.content.components(separatedBy: .newlines).first ?? "")
                .lineLimit(1)
                .truncationMode(.tail)

            if editingMessage.message.content.contains("\n") ||
                editingMessage.message.content.count > 100 {  // Show (more) if multiline or long
                Text("(more)")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditable {
                onEditRequested()
            } else {
                onExpandRequested()
            }
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

    var body: some View {
        VStack(alignment: .leading) {
            if editingMessage.rowMode == .compact {
                HStack(alignment: .top) {
                    roleSelector
                        .matchedGeometryEffect(id: "RoleSelector", in: animation)
                    compactView
                        .matchedGeometryEffect(id: "Content", in: animation, anchor: UnitPoint.topLeading)
                    editButton
                        .matchedGeometryEffect(id: "EditButton", in: animation)
                }
            } else if editingMessage.rowMode == .edit || editingMessage.rowMode == .full {
                VStack(alignment: .leading) {
                    roleSelector
                        .matchedGeometryEffect(id: "RoleSelector", in: animation)
                    HStack(alignment: .top) {
                        VStack(spacing: 3) {
                            ZStack(alignment: .bottomTrailing) {
                                editView
                                    .opacity(rowMode == .full || isEditable == false ? 0.7 : 1.0)
                                    .disabled(rowMode == .full || isEditable == false)
                                    .matchedGeometryEffect(id: "Content", in: animation, anchor: UnitPoint.topLeading)
                                copyButton
                            }
                            bottomTools
                                .opacity(rowMode == .full || isEditable == false ? 0.0 : 1.0)
                        }
                        editButton
                            .opacity(rowMode == .full ? 1.0 : 0.0)
                            .matchedGeometryEffect(id: "EditButton", in: animation)
                    }
                }
            } else {
                // unknown - future mode
                fatalError(">>> Unknown mode \(editingMessage.rowMode)")
            }
        }
//        .onChange(of: editingMessage.message) {
//            print("@@@ onChange of message \(editingMessage.message) originalRole: \(originalRole?.rawValue)")
//        }
        .onChange(of: isEditable) { old, new in
            print("@@@ onChange \(old) \(new)")
            if new == false && rowMode == .edit {
                setRowMode(.full)
            }
        }
        .onChange(of: rowMode) { old, new in
            print("@@@ onChange \(old) \(new)")
            if new == .edit {
                if !isEditable {
                    Task { @MainActor in isTextFieldFocused = false }
                } else {
                    Task {
                        @MainActor in isTextFieldFocused = true
                        onEditingBegan()
                    }
                }
            }
            if (new == .compact || new == .full) && old == .edit {
                isTextFieldFocused = false
                handleConfirm()
            }
        }
        .padding()
        .animation(.spring(), value: editingMessage.rowMode)
        .transition(.move(edge: .bottom))
        .onAppear {
            editingText = editingMessage.message.content
            originalRole = editingMessage.message.role
            if rowMode == .edit {
                isTextFieldFocused = true
            }
        }
        .onDisappear {
            copyConfirmationTask?.cancel()
        }
    }
}

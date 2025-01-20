import SwiftUI

enum MessageRowMode {
    case compact
    case full
    case edit
}

struct MessageRow: View {
    @EnvironmentObject private var state: MessageListState
    @Binding var message: LLMMessage
    @Binding var mode: MessageRowMode
    @State private var editingText: String = ""
    
    let confirmButtonTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onCopy: () -> Void
    
    @State private var showingCopyConfirmation = false
    @State private var copyConfirmationTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool
    
    private func formatMessage(_ text: String) -> AttributedString {
        do {
            let options = AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace
            )
            var attributed = try AttributedString(markdown: text, options: options)
            if case .other = message.role {
                attributed.foregroundColor = .secondary
            }
            return attributed
        } catch {
            return AttributedString(text)
        }
    }
    
    private func handleKeyPress(_ press: KeyPress) -> KeyPress.Result {
        // Only handle key down phase
        guard press.phase == .down else { return .ignored }
        
        switch (press.key, press.modifiers) {
        case (.return, let mods) where mods.contains(.command):
            handleConfirm()
            return .handled
        case (.return, let mods) where mods.contains(.shift):
            handleConfirm()
            return .handled
        case (.escape, _):
            onCancel()
            return .handled
        case (.tab, _):
            let cursorPosition = editingText.count
            editingText.insert(contentsOf: "    ", at: editingText.index(editingText.startIndex, offsetBy: cursorPosition))
            return .handled
        default:
            return .ignored
        }
    }
    
    private func enterEditMode() {
        editingText = message.content
        isTextFieldFocused = true
    }
    
    private func handleConfirm() {
        let trimmedText = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            withAnimation {
                onConfirm()
                state.removeMessage(message.id)
            }
        } else {
            message.content = trimmedText
            onConfirm()
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if mode == .compact {
                HStack(alignment: .top, spacing: 8) {
                    RoleSelector(
                        role: $message.role,
                        isEditable: state.isEditable,
                        onCustomRole: { newRole in
                            state.addCustomRole(newRole)
                            message.role = .other(newRole)
                        }
                    )
                    
                    HStack(spacing: 4) {
                        Text(message.content.components(separatedBy: .newlines).first ?? "")
                            .lineLimit(1)
                            .truncationMode(.tail)
                        
                        if message.content.contains("\n") || 
                           message.content.count > 100 {  // Show (more) if multiline or long
                            Text("(more)")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    mode = state.isEditable ? .edit : .full
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        RoleSelector(
                            role: $message.role,
                            isEditable: state.isEditable,
                            onCustomRole: { newRole in
                                state.addCustomRole(newRole)
                                message.role = .other(newRole)
                            }
                        )
                        .opacity(state.isEditable ? 1.0 : 0.7)
                        
                        if mode == .edit {
                            TextEditor(text: $editingText)
                                .font(.body)
                                .frame(minHeight: 100)
                                .focusable()
                                .focused($isTextFieldFocused)
                                .onKeyPress { press in
                                    handleKeyPress(press)
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.secondary.opacity(0.2))
                                )
                                .accessibilityLabel("Message content")
                                .accessibilityHint("Enter your message")
                            
                            // Add a hidden button to handle option-r
                            Button(action: {
                                if state.isEditable {
                                    cycleRole()
                                }
                            }) {
                                EmptyView()
                            }
                            .keyboardShortcut("r", modifiers: .option)
                            .opacity(0)  // Hide the button but keep it functional
                        } else {
                            Text(formatMessage(message.content))
                                .textSelection(.enabled)
                                .accessibilityLabel("Message: \(message.content)")
                        }
                    }
                    
                    HStack(spacing: 8) {
                        
                        if mode == .edit {
                            Button("Cancel") {
                                onCancel()
                            }
                            .buttonStyle(.bordered)
                            .keyboardShortcut(.escape, modifiers: [])
                            .accessibilityLabel("Cancel editing")
                        }
                        
                        Spacer()
                        
                        Button(action: {
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
                        .buttonStyle(.plain)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        
                        if mode == .edit {
                            Button(confirmButtonTitle) {
                                handleConfirm()
                            }
                            .buttonStyle(.borderedProminent)
                            .keyboardShortcut(.return, modifiers: [.command])
//                            .keyboardShortcut(.return, modifiers: [.command, .option])
                            .accessibilityLabel("Confirm changes")
                        }
                    }
                }
            }
        }
        .padding()
        .animation(.spring(), value: mode)
        .transition(.move(edge: .bottom))
        .onChange(of: mode) { _, newMode in
            if newMode == .edit {
                // Use Task to ensure focus happens after view update
                Task { @MainActor in
                    enterEditMode()
                }
            }
        }
        .onDisappear {
            copyConfirmationTask?.cancel()
        }
        .onChange(of: message.id) { _, _ in
            // If the message changes (which can happen during removal),
            // ensure we exit edit mode and clean up
            if mode == .edit {
                handleConfirm()
                mode = .compact
            }
        }
    }
    
    private func cycleRole() {
        switch message.role {
        case .system: message.role = .user
        case .user: message.role = .assistant
        case .assistant: message.role = .system
        case .other: message.role = .system
        }
    }
} 

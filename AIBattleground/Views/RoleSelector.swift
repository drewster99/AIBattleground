import SwiftUI

struct RoleSelector: View {
    @Binding var role: LLMMessage.MessageRole
    let isEditable: Bool
    let onCustomRole: (String) -> Void
    
    @State private var showingCustomRoleInput = false
    @State private var customRoleText = ""
    
    // Calculate fixed width based on widest built-in role
    private static let fixedWidth: CGFloat = {
        let builtInRoles = ["System", "Assistant", "User"]  // Using displayNames
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        return builtInRoles.map { (text: String) -> CGFloat in
            let attributes = [NSAttributedString.Key.font: font]
            let size = (text as NSString).size(withAttributes: attributes)
            return size.width
        }.max() ?? 60
    }()
    
    var body: some View {
        Text(role.displayName)
            .frame(width: Self.fixedWidth + 16)  // Add padding to fixed width
            .background(role.backgroundColor.opacity(0.2))
            .foregroundStyle(role.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEditable ? 1.0 : 0.7)
            .focusable()
            .onTapGesture {
                if isEditable {
                    cycleRole()
                }
            }
            .gesture(
                TapGesture(count: 2)
                    .onEnded {
                        if isEditable {
                            showingCustomRoleInput = true
                        }
                    }
                    .exclusively(before: TapGesture(count: 1)
                        .onEnded {
                            if isEditable {
                                cycleRole()
                            }
                        }
                    )
            )
            .popover(isPresented: $showingCustomRoleInput) {
                VStack {
                    TextField("Custom Role", text: $customRoleText)
                        .textFieldStyle(.roundedBorder)
                        .padding()
                    
                    Button("Done") {
                        if !customRoleText.isEmpty {
                            onCustomRole(customRoleText)
                        }
                        showingCustomRoleInput = false
                        customRoleText = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom)
                }
                .frame(width: 200)
            }
    }
    
    private func cycleRole() {
        switch role {
        case .system: role = .user
        case .user: role = .assistant
        case .assistant: role = .system
        case .other: role = .system
        }
    }
} 

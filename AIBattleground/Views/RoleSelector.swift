import SwiftUI

class CustomRolesManager: ObservableObject {
    @Published public var customRoles: Set<LLMMessage.MessageRole> = []

    public func nextRole(after role: LLMMessage.MessageRole) -> LLMMessage.MessageRole {
        // Update customRoles, if needed
        let defaultRoles = [LLMMessage.MessageRole.user, .assistant, .system]
        let otherRoles = customRoles.sorted { lhs, rhs in
            lhs.rawValue < rhs.rawValue
        }
        var allRoles = defaultRoles
        allRoles.append(contentsOf: otherRoles)
        if let newIndex = allRoles.firstIndex(of: role)?.advanced(by: 1), allRoles.indices.contains(newIndex) {
            return allRoles[newIndex]
        } else {
            return allRoles.first ?? .user
        }
    }
}
struct RoleSelector: View {
    @EnvironmentObject private var rolesManager: CustomRolesManager
    @Binding var role: LLMMessage.MessageRole
    
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
            .clipShape(RoundedRectangle(cornerRadius: 4))
//            .onTapGesture {
//                role = rolesManager.nextRole(after: role)
//            }
            .gesture(
                LongPressGesture()
//                    .onChanged { _ in
//                    }
                    .onEnded {_ in 
                        showingCustomRoleInput = true
                    }
                    .exclusively(before: TapGesture(count: 1)
                        .onEnded {
                            role = rolesManager.nextRole(after: role)
                        }
                    )
            )
            .popover(isPresented: $showingCustomRoleInput) {
                VStack {
                    TextField("Custom Role", text: $customRoleText)
                        .textFieldStyle(.roundedBorder)
                        .padding()

                    Button("Done") {
                        if !customRoleText.isEmpty, let newRole = LLMMessage.MessageRole(rawValue: customRoleText) {
                            rolesManager.customRoles.insert(newRole)
                            role = newRole
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
} 

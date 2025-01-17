import Foundation
import SwiftUI

enum CredentialSheetMode {
    case add
    case edit(LLMServiceConfiguration)
}

struct CredentialSheet: View {
    let mode: CredentialSheetMode
    let onSave: () -> Void

    @EnvironmentObject private var serviceManager: LLMServiceManager
    @Environment(\.dismiss) private var dismiss
    @State private var apiKey = ""
    @State private var username = ""
    @State private var comment = ""
    @State private var name = ""
    @State private var endpointURL = ""
    @State private var thumbnailURL = ""
    @State private var selectedProtocolDriver: LLMProtocolDriverDescription = .openai
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var originalValues: (
        apiKey: String, 
        username: String, 
        comment: String,
        name: String,
        endpointURL: String,
        thumbnailURL: String,
        protocolDriver: LLMProtocolDriverDescription
    )?
    @FocusState private var focusedField: FocusableField?
    private enum FocusableField: Hashable, Equatable {
        case apiKey
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }
    
    private var hasChanges: Bool {
        guard let original = originalValues else { return true }
        return original.apiKey != apiKey 
            || original.username != username
            || original.comment != comment
            || original.name != name
            || original.endpointURL != endpointURL
            || original.thumbnailURL != thumbnailURL
            || original.protocolDriver != selectedProtocolDriver
    }

    private var shouldFocusApiKeyField: Bool {
        !name.isEmpty && !endpointURL.isEmpty && !thumbnailURL.isEmpty && apiKey.isEmpty
    }

    var body: some View {
        VStack(spacing: 14) {
            // Header with large icon and name
            if case .edit(let service) = mode {
                VStack(spacing: 16) {
                    HStack(alignment: .center) {
                        if let imageURL = service.thumbnailImageURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 40, height: 40)
                        }
                        Text(service.name)
                            .font(.system(size: 32, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 20)
            }
            
            Form {
                Section("Service Information") {
                    HStack {
                        Text("Name")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 1)
                    
                    HStack {
                        Text("Comment")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $comment)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 1)
                }
                .padding(.vertical, 1)

                Section("API Protocol") {
                    Picker("Protocol", selection: $selectedProtocolDriver) {
                        ForEach(LLMProtocolDriverDescription.allCases) { protocolDriver in
                            HStack {
                                if let imageURL = protocolDriver.imageURL {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable()
                                    } placeholder: {
                                        Color.gray
                                    }
                                    .frame(width: 16, height: 16)
                                }
                                Text(protocolDriver.displayName)
                            }
                            .tag(protocolDriver)
                        }
                    }
                    .pickerStyle(.menu)
                    .padding(.vertical, 1)
                }
                .padding(.vertical, 1)

                Section("API Configuration") {
                    HStack {
                        Text("Base URL")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $endpointURL)
                            .textContentType(.URL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 1)
                    
                    HStack {
                        Text("API Key")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $apiKey)
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .focused($focusedField, equals: .apiKey)
                    }
                    .padding(.vertical, 1)
                    
                    HStack {
                        Text("Username")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $username)
                            .textFieldStyle(.roundedBorder)
                    }
                    .padding(.vertical, 1)
                }
                .padding(.vertical, 1)

                Section("Display") {
                    HStack {
                        Text("Icon URL")
                            .frame(width: 100, alignment: .leading)
                        TextField("", text: $thumbnailURL)
                            .textContentType(.URL)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    .padding(.vertical, 1)
                }
                .padding(.vertical, 1)
            }
            .formStyle(.grouped)

            // Footer
            VStack(spacing: 12) {
                // Buttons
                HStack(spacing: 16) {
                    if isEditing {
                        Button(role: .destructive) {
                            deleteService()
                        } label: {
                            Text("Delete")
                                .frame(minWidth: 80)
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .frame(minWidth: 80)

                    Button(isEditing ? "Update" : "Add") {
                        saveService()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minWidth: 80)
                    .disabled(apiKey.isEmpty || !hasChanges)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
            .padding(.bottom, 10)
        }
        .padding()
        .onAppear {
            if case .edit(let service) = mode {
                apiKey = service.apiKey ?? ""
                username = service.username ?? ""
                comment = service.comment ?? ""
                name = service.name
                endpointURL = service.endpointURL.absoluteString
                thumbnailURL = service.thumbnailImageURL?.absoluteString ?? ""
                selectedProtocolDriver = service.protocolDriver
                
                originalValues = (
                    apiKey: apiKey,
                    username: username,
                    comment: comment,
                    name: name,
                    endpointURL: endpointURL,
                    thumbnailURL: thumbnailURL,
                    protocolDriver: selectedProtocolDriver
                )
            } else {
                selectedProtocolDriver = .openai
                endpointURL = selectedProtocolDriver.defaultBaseURL.absoluteString
            }

            if shouldFocusApiKeyField {
                focusedField = .apiKey
            }
        }
        .alert(
            "Error",
            isPresented: $showingError,
            actions: {
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        )
    }
    
    private func saveService() {
        Task {
            do {
                guard let endpointURL = URL(string: endpointURL) else {
                    errorMessage = "Invalid endpoint URL"
                    showingError = true
                    return
                }
                
                let thumbnailURL = URL(string: thumbnailURL)
                
                if isEditing {
                    if case .edit(let service) = mode {
                        let newService = LLMServiceConfiguration(
                            id: service.id,
                            name: name,
                            comment: comment,
                            username: username,
                            protocolDriver: selectedProtocolDriver,
                            endpointURL: endpointURL,
                            thumbnailImageURL: thumbnailURL
                        )
                        try await newService.setApiKey(apiKey)
                        try await serviceManager.update(newService)
                    }
                } else {
                    let newID = LLMServiceConfiguration.ID()
                    let newService = LLMServiceConfiguration(
                        id: newID,
                        name: name,
                        comment: comment,
                        username: username,
                        protocolDriver: selectedProtocolDriver,
                        endpointURL: endpointURL,
                        thumbnailImageURL: thumbnailURL
                    )
                    try await newService.setApiKey(apiKey)
                    try await serviceManager.add(newService)
                }
                onSave()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
    
    private func deleteService() {
        Task {
            if case .edit(let service) = mode {
                do {
                    try await serviceManager.delete(service)
                    onSave()
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
} 

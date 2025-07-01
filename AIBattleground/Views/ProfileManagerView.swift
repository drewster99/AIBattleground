import Foundation
import SwiftUI

struct ProfileManagerView: View {
    @EnvironmentObject private var modelManager: LLMModelManager
    @EnvironmentObject private var serviceManager: LLMServiceManager
    @StateObject private var profileManager = LLMProfileManager.shared
    @State private var isAddingProfile = false
    @State private var isEditingProfile = false
    @State private var selectedProfileIndex: Int?
    @State private var searchText = ""
    @State private var showingDefaultProfiles = false
    
    private var filteredProfiles: [LLMModelProfile] {
        let profilesToFilter = showingDefaultProfiles ? 
            Array(profileManager.defaultProfiles.values) : 
            profileManager.profiles
            
        if searchText.isEmpty {
            return profilesToFilter
        }
        
        let searchTerms = searchText.lowercased().split(separator: " ")
        return profilesToFilter.filter { profile in
            searchTerms.allSatisfy { term in
                if profile.name.lowercased().contains(term) {
                    return true
                }
                if profile.description.lowercased().contains(term) {
                    return true
                }
                if profile.modelEntry.id.lowercased().contains(term) {
                    return true
                }
                if profile.modelEntry.provider.lowercased().contains(term) {
                    return true
                }
                return false
            }
        }
    }
    
    // Get service configuration for a profile
    private func getServiceForProfile(_ profile: LLMModelProfile) -> LLMServiceConfiguration? {
        let provider = profile.modelEntry.provider
        return serviceManager.services.first { service in
            service.protocolDriver.displayName == provider
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search and filter controls
            HStack {
                TextField("Search profiles...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Picker("", selection: $showingDefaultProfiles) {
                    Text("User Profiles").tag(false)
                    Text("Default Profiles").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                .padding(.trailing)
                
                Button(action: {
                    isAddingProfile = true
                }) {
                    Label("Add Profile", systemImage: "plus")
                }
                .padding(.trailing)
                .disabled(showingDefaultProfiles)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Profiles list
            List {
                ForEach(Array(filteredProfiles.enumerated()), id: \.element.id) { index, profile in
                    ProfileRow(
                        profile: profile,
                        service: getServiceForProfile(profile),
                        isDefault: profileManager.isDefaultProfile(profile)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !showingDefaultProfiles {
                            selectedProfileIndex = index
                            isEditingProfile = true
                        } else {
                            // For default profiles, we'll create a new user profile based on this default
                            isAddingProfile = true
                            // We'll handle this in the sheet presentation
                        }
                    }
                    .contextMenu {
                        if !showingDefaultProfiles {
                            Button(action: {
                                selectedProfileIndex = index
                                isEditingProfile = true
                            }) {
                                Label("Edit", systemImage: "pencil")
                            }
                            
                            Button(role: .destructive, action: {
                                Task {
                                    do {
                                        try await profileManager.deleteProfile(at: index)
                                    } catch {
                                        print("Error deleting profile: \(error.localizedDescription)")
                                    }
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .navigationTitle("Profiles")
        .frame(minWidth: 800, minHeight: 600)
        .sheet(isPresented: $isAddingProfile) {
            ProfileEditorView(mode: .add)
                .frame(minWidth: 600, minHeight: 700)
        }
        .sheet(isPresented: $isEditingProfile) {
            if let index = selectedProfileIndex, 
               !showingDefaultProfiles,
               index < profileManager.profiles.count {
                ProfileEditorView(mode: .edit(profileManager.profiles[index], index: index))
                    .frame(minWidth: 600, minHeight: 700)
            }
        }
    }
}

struct ProfileRow: View {
    let profile: LLMModelProfile
    let service: LLMServiceConfiguration?
    let isDefault: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Service thumbnail
            if let service = service, let imageURL = service.thumbnailImageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "cpu.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .padding(4)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(profile.name)
                        .font(.headline)
                    
                    if isDefault {
                        Text("Default")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(profile.modelEntry.provider)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                Text(profile.modelEntry.id)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if !profile.description.isEmpty {
                    Text(profile.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                // Display key settings
                HStack(spacing: 12) {
                    SettingBadge(
                        label: "Temp",
                        value: String(format: "%.2f", profile.modelSettings.temperature ?? 1.0)
                    )
                    
                    SettingBadge(
                        label: "Max Tokens",
                        value: "\(profile.modelSettings.maxTokens ?? 1024)"
                    )
                    
                    if let topP = profile.modelSettings.top_p {
                        SettingBadge(
                            label: "Top P",
                            value: String(format: "%.2f", topP)
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

struct SettingBadge: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

struct ProfileEditorView: View {
    enum Mode {
        case add
        case edit(LLMModelProfile, index: Int)
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var modelManager: LLMModelManager
    @EnvironmentObject private var serviceManager: LLMServiceManager
    @StateObject private var profileManager = LLMProfileManager.shared
    
    @State private var selectedModelId: String = ""
    @State private var profileName: String = ""
    @State private var profileDescription: String = ""
    @State private var modelSettings: LLMModelSettings
    @State private var isDefault: Bool = false
    
    // Settings fields
    @State private var temperature: Double = 1.0
    @State private var maxTokens: Int = 1024
    @State private var topP: Double = 1.0
    
    init(mode: Mode) {
        self.mode = mode
        
        // Initialize with default settings
        let defaultSettings = LLMModelSettings(
            id: UUID(),
            name: ""
        )
        
        // If editing, use the profile's settings
        switch mode {
        case .add:
            _modelSettings = State(initialValue: defaultSettings)
            _profileName = State(initialValue: "")
            _profileDescription = State(initialValue: "")
            _selectedModelId = State(initialValue: "")
        case .edit(let profile, _):
            _modelSettings = State(initialValue: profile.modelSettings)
            _profileName = State(initialValue: profile.name)
            _profileDescription = State(initialValue: profile.description)
            _selectedModelId = State(initialValue: profile.modelEntry.id)
            _temperature = State(initialValue: profile.modelSettings.temperature ?? 1.0)
            _maxTokens = State(initialValue: profile.modelSettings.maxTokens ?? 1024)
            _topP = State(initialValue: profile.modelSettings.top_p ?? 1.0)
            _isDefault = State(initialValue: LLMProfileManager.shared.isDefaultProfile(profile))
        }
    }
    
    private var availableModels: [LLMAvailableModelEntry] {
        // Flatten all models from all services
        let allModels = modelManager.enabledModels.map { $0.modelEntry }
        
        // Remove duplicates by ID
        var uniqueModels: [LLMAvailableModelEntry] = []
        var seenIds = Set<String>()
        
        for model in allModels {
            if !seenIds.contains(model.id) {
                uniqueModels.append(model)
                seenIds.insert(model.id)
            }
        }
        
        return uniqueModels.sorted { ($0.displayName ?? $0.id) < ($1.displayName ?? $1.id) }
    }
    
    private var selectedModel: LLMAvailableModelEntry? {
        availableModels.first { $0.id == selectedModelId }
    }
    
    // Get service configuration for a model
    private func getServiceForModel(_ modelId: String) -> LLMServiceConfiguration? {
        guard let model = modelManager.enabledModels.first(where: { $0.modelEntry.id == modelId }) else {
            return nil
        }
        return model.configuration
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Profile Name", text: $profileName)
                        .padding(.vertical, 4)
                    
                    TextField("Description", text: $profileDescription)
                        .lineLimit(3)
                        .padding(.vertical, 4)
                    
                    if case .edit = mode {
                        Toggle("Set as Default for this Model", isOn: $isDefault)
                            .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("Model Selection")) {
                    HStack {
                        if let model = selectedModel, 
                           let service = getServiceForModel(model.id),
                           let imageURL = service.thumbnailImageURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable()
                            } placeholder: {
                                Color.gray
                            }
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        Picker("Model", selection: $selectedModelId) {
                            Text("Select a model").tag("")
                            
                            ForEach(availableModels, id: \.id) { model in
                                Text(model.displayName ?? model.id)
                                    .tag(model.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Model Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Temperature: \(temperature, specifier: "%.2f")")
                        
                        HStack {
                            Text("0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $temperature, in: 0...2, step: 0.01)
                            
                            Text("2.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Controls randomness: Lower values are more deterministic, higher values more creative.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 1...8192, step: 128)
                        
                        Text("Maximum number of tokens to generate in the response.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top P: \(topP, specifier: "%.2f")")
                        
                        HStack {
                            Text("0.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Slider(value: $topP, in: 0...1, step: 0.01)
                            
                            Text("1.0")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("Controls diversity via nucleus sampling: 0.5 means half of all likelihood-weighted options are considered.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(mode.isAdd ? "Add Profile" : "Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(selectedModelId.isEmpty || profileName.isEmpty)
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let model = selectedModel else { return }
        
        // Update settings with current values
        var updatedSettings = modelSettings
        updatedSettings.name = profileName
        updatedSettings.temperature = temperature
        updatedSettings.maxTokens = maxTokens
        updatedSettings.top_p = topP
        
        let profile = LLMModelProfile(
            modelEntry: model,
            modelSettings: updatedSettings
        )
        
        Task {
            switch mode {
            case .add:
                await profileManager.addProfile(profile)
                
                // If this is set as default, update the default profile
                if isDefault {
                    await profileManager.setDefaultProfile(for: model.id, profile: profile)
                }
                
            case .edit(_, let index):
                do {
                    try await profileManager.updateProfile(at: index, with: profile)
                    
                    // Update default profile if needed
                    if isDefault {
                        await profileManager.setDefaultProfile(for: model.id, profile: profile)
                    }
                } catch {
                    print("Error updating profile: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                dismiss()
            }
        }
    }
}

extension ProfileEditorView.Mode {
    var isAdd: Bool {
        if case .add = self {
            return true
        }
        return false
    }
} 
import Foundation
import SwiftUI

struct ProfileManagerView: View {
    @EnvironmentObject private var modelManager: LLMModelManager
    @StateObject private var profileManager = LLMProfileManager.shared
    @State private var isAddingProfile = false
    @State private var isEditingProfile = false
    @State private var selectedProfileIndex: Int?
    @State private var searchText = ""
    
    private var filteredProfiles: [LLMModelProfile] {
        if searchText.isEmpty {
            return profileManager.profiles
        }
        
        let searchTerms = searchText.lowercased().split(separator: " ")
        return profileManager.profiles.filter { profile in
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
    
    var body: some View {
        VStack {
            HStack {
                TextField("Search profiles...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button(action: {
                    isAddingProfile = true
                }) {
                    Label("Add Profile", systemImage: "plus")
                }
                .padding(.trailing)
            }
            .padding(.top)
            
            List {
                ForEach(Array(filteredProfiles.enumerated()), id: \.element.id) { index, profile in
                    ProfileRow(profile: profile)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedProfileIndex = index
                            isEditingProfile = true
                        }
                        .contextMenu {
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
        .navigationTitle("Profiles")
        .sheet(isPresented: $isAddingProfile) {
            ProfileEditorView(mode: .add)
        }
        .sheet(isPresented: $isEditingProfile) {
            if let index = selectedProfileIndex, index < profileManager.profiles.count {
                ProfileEditorView(mode: .edit(profileManager.profiles[index], index: index))
            }
        }
    }
}

struct ProfileRow: View {
    let profile: LLMModelProfile
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                
                Spacer()
                
                Text(profile.modelEntry.provider)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
        }
        .padding(.vertical, 4)
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
    @StateObject private var profileManager = LLMProfileManager.shared
    
    @State private var selectedModelId: String = ""
    @State private var profileName: String = ""
    @State private var profileDescription: String = ""
    @State private var modelSettings: LLMModelSettings
    
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
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile Information")) {
                    TextField("Profile Name", text: $profileName)
                    
                    TextField("Description", text: $profileDescription)
                        .lineLimit(3)
                }
                
                Section(header: Text("Model Selection")) {
                    Picker("Model", selection: $selectedModelId) {
                        Text("Select a model").tag("")
                        
                        ForEach(availableModels, id: \.id) { model in
                            Text(model.displayName ?? model.id)
                                .tag(model.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section(header: Text("Model Settings")) {
                    VStack {
                        HStack {
                            Text("Temperature: \(temperature, specifier: "%.2f")")
                            Spacer()
                        }
                        Slider(value: $temperature, in: 0...2, step: 0.01)
                    }
                    
                    Stepper("Max Tokens: \(maxTokens)", value: $maxTokens, in: 1...8192, step: 128)
                    
                    VStack {
                        HStack {
                            Text("Top P: \(topP, specifier: "%.2f")")
                            Spacer()
                        }
                        Slider(value: $topP, in: 0...1, step: 0.01)
                    }
                }
            }
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
        .frame(minWidth: 500, minHeight: 600)
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
            case .edit(_, let index):
                do {
                    try await profileManager.updateProfile(at: index, with: profile)
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
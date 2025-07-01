import Foundation

actor LLMProfileManager: ObservableObject {
    public static let shared = LLMProfileManager()
    
    private let defaults = UserDefaults.standard
    private let profilesKey = "llm_model_profiles"
    private let defaultProfilesKey = "default_model_profiles"
    
    @MainActor @Published private(set) var profiles: [LLMModelProfile] = []
    @MainActor @Published private(set) var defaultProfiles: [String: LLMModelProfile] = [:]
    
    private init() {
        Task {
            await loadProfiles()
        }
    }
    
    @MainActor
    private func loadProfiles() {
        // Load user profiles
        if let data = defaults.data(forKey: profilesKey) {
            do {
                let decoder = JSONDecoder()
                let loadedProfiles = try decoder.decode([LLMModelProfile].self, from: data)
                self.profiles = loadedProfiles
            } catch {
                print("Error loading profiles: \(error.localizedDescription)")
                self.profiles = []
            }
        }
        
        // Load default profiles
        if let data = defaults.data(forKey: defaultProfilesKey) {
            do {
                let decoder = JSONDecoder()
                let loadedDefaults = try decoder.decode([String: LLMModelProfile].self, from: data)
                self.defaultProfiles = loadedDefaults
            } catch {
                print("Error loading default profiles: \(error.localizedDescription)")
                self.defaultProfiles = [:]
            }
        }
    }
    
    @MainActor
    private func saveProfiles() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(profiles)
            defaults.set(data, forKey: profilesKey)
        } catch {
            print("Error saving profiles: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func saveDefaultProfiles() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(defaultProfiles)
            defaults.set(data, forKey: defaultProfilesKey)
        } catch {
            print("Error saving default profiles: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    func addProfile(_ profile: LLMModelProfile) {
        // Check if profile with same ID already exists
        if !profiles.contains(where: { $0.id == profile.id }) {
            profiles.append(profile)
            saveProfiles()
        }
    }
    
    @MainActor
    func updateProfile(at index: Int, with profile: LLMModelProfile) throws {
        guard index >= 0 && index < profiles.count else {
            throw LLMProfileError.invalidIndex
        }
        
        profiles[index] = profile
        saveProfiles()
    }
    
    @MainActor
    func deleteProfile(at index: Int) throws {
        guard index >= 0 && index < profiles.count else {
            throw LLMProfileError.invalidIndex
        }
        
        profiles.remove(at: index)
        saveProfiles()
    }
    
    @MainActor
    func deleteProfile(withId id: String) {
        profiles.removeAll(where: { $0.id == id })
        saveProfiles()
    }
    
    @MainActor
    func setDefaultProfile(for modelId: String, profile: LLMModelProfile) {
        defaultProfiles[modelId] = profile
        saveDefaultProfiles()
    }
    
    @MainActor
    func getDefaultProfile(for modelId: String) -> LLMModelProfile? {
        return defaultProfiles[modelId]
    }
    
    @MainActor
    func getProfileForModel(modelEntry: LLMAvailableModelEntry, modelSettings: LLMModelSettings) -> LLMModelProfile {
        // Check if we have a user-created profile for this model
        if let existingProfile = profiles.first(where: { $0.modelEntry.id == modelEntry.id }) {
            return existingProfile
        }
        
        // Check if we have a default profile for this model
        if let defaultProfile = defaultProfiles[modelEntry.id] {
            return defaultProfile
        }
        
        // Create a new default profile
        let newDefaultProfile = LLMModelProfile(modelEntry: modelEntry, modelSettings: modelSettings)
        defaultProfiles[modelEntry.id] = newDefaultProfile
        saveDefaultProfiles()
        
        return newDefaultProfile
    }
    
    @MainActor
    func isDefaultProfile(_ profile: LLMModelProfile) -> Bool {
        return defaultProfiles.values.contains(where: { $0.id == profile.id })
    }
    
    @MainActor
    func updateDefaultProfiles(with newSettings: LLMModelSettings, for modelId: String) {
        if let defaultProfile = defaultProfiles[modelId] {
            let updatedProfile = LLMModelProfile(
                modelEntry: defaultProfile.modelEntry,
                modelSettings: newSettings
            )
            defaultProfiles[modelId] = updatedProfile
            saveDefaultProfiles()
        }
    }
}

enum LLMProfileError: Error {
    case invalidIndex
} 
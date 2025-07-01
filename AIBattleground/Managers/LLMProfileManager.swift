import Foundation

actor LLMProfileManager: ObservableObject {
    public static let shared = LLMProfileManager()
    
    private let defaults = UserDefaults.standard
    private let profilesKey = "llm_model_profiles"
    
    @MainActor @Published private(set) var profiles: [LLMModelProfile] = []
    
    private init() {
        Task {
            await loadProfiles()
        }
    }
    
    @MainActor
    private func loadProfiles() {
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
}

enum LLMProfileError: Error {
    case invalidIndex
} 
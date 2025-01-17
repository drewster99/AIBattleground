import Foundation

struct LLMModelProfile: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let description: String
    let modelEntry: LLMAvailableModelEntry
    let modelSettings: LLMModelSettings

    init(modelEntry: LLMAvailableModelEntry, modelSettings: LLMModelSettings) {
        self.id = modelEntry.id
        self.name = modelEntry.displayName ?? modelEntry.id
        self.description = modelEntry.description ?? ""
        self.modelEntry = modelEntry
        self.modelSettings = modelSettings
    }

    var modelProfile: LLMModelProfile {
        return LLMModelProfile(modelEntry: modelEntry, modelSettings: modelSettings)
    }
}
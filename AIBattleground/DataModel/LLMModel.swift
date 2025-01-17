import Foundation

struct LLMModel: Identifiable, Equatable {
    let id: String
    let configuration: LLMServiceConfiguration
    let modelEntry: LLMAvailableModelEntry
    let modelSettings: LLMModelSettings
    
    init(configuration: LLMServiceConfiguration, modelEntry: LLMAvailableModelEntry, modelSettings: LLMModelSettings) {
        self.id = "\(configuration.id):\(modelEntry.id)"
        self.configuration = configuration
        self.modelEntry = modelEntry
        self.modelSettings = modelSettings
    }

    var modelProfile: LLMModelProfile {
        return LLMModelProfile(modelEntry: modelEntry, modelSettings: modelSettings)
    }
} 

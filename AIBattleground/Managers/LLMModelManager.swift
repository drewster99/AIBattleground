import Foundation

actor LLMModelManager: ObservableObject {
    public static let shared = LLMModelManager()
    
    private let defaults = UserDefaults.standard
    private let disabledModelsKey = "disabled_model_ids"
    
    // Models that should be filtered out due to incompatibility or different use cases
    private let incompatibleModels: Set<String> = [
        "text-embedding-004",    // Embedding model
        "aqa",                   // Question answering model
        "dall-e-2",             // Image generation
        "dall-e-3",             // Image generation
        "tts-1",                // Text to speech
        "tts-1-hd",             // Text to speech HD
        "tts-1-1106",
        "tts-1-hd-1106",
        "whisper-1",             // Speech to text
        "gpt-4o-realtime-preview",
        "gpt-4o-mini-realtime-preview",
        "gpt-3.5-turbo-instruct",
        "gpt-3.5-turbo-instruct-0914",
        "babbage-002",
        "davinci-002",
        "text-embedding-ada-002",
        "text-embedding-3-small",
        "text-embedding-3-large",
        "gpt-4o-mini-realtime-preview-2024-12-17",
        "gpt-4o-realtime-preview-2024-10-01",
        "gpt-4o-realtime-preview-2024-12-17",
        "omni-moderation-2024-09-26",
        "omni-moderation-latest"
    ]
    
    @MainActor @Published private(set) var models: [LLMModel] = []
    @MainActor @Published private(set) var enabledModels: [LLMModel] = []
    @MainActor @Published private(set) var disabledModels: [LLMModel] = []
    @MainActor @Published private(set) var isRefreshing = false
    @MainActor @Published private(set) var serviceErrors: [(service: LLMServiceConfiguration, error: Error)] = []
    
    
    private var disabledModelIds: Set<String> {
        get { Set(defaults.stringArray(forKey: disabledModelsKey) ?? []) }
        set { defaults.set(Array(newValue), forKey: disabledModelsKey) }
    }
    
    private init() {
        Task {
            await refreshAvailableModels(for: LLMServiceManager.shared.services)
        }
    }
    
    func refreshAvailableModels(for configurations: [LLMServiceConfiguration]) async {
        guard await !isRefreshing else { return }
        Task { @MainActor in
            isRefreshing = true
            serviceErrors = []
        }
        
        print("Starting model refresh for \(configurations.count) configurations")
        var newModels: [LLMModel] = []
        
        for config in configurations {
            print("\nProcessing configuration: \(config.name)")
            print("Creating service for \(config.name) with endpoint \(config.endpointURL)")
            
            let service = config.protocolDriver.serviceType.init(
                configuration: config
            )
            
            do {
                print("Fetching models for \(config.name)...")
                let availableModels = try await withCheckedThrowingContinuation { continuation in
                    service.getAvailableModels { result in
                        continuation.resume(with: result)
                    }
                }
                print("Successfully fetched \(availableModels.count) models for \(config.name)")
                
                let configModels = availableModels.map { modelEntry in
                    let modelSettings = LLMModelSettings(
                        id: UUID(),
                        name: modelEntry.displayName ?? modelEntry.id,
                        comment: modelEntry.description
                    )
                    
                    return LLMModel(
                        configuration: config,
                        modelEntry: modelEntry,
                        modelSettings: modelSettings
                    )
                }
                
                newModels.append(contentsOf: configModels)
                print("Added \(configModels.count) models for \(config.name)")
            } catch {
                Task { @MainActor in 
                    serviceErrors.append((service: config, error: error))
                }
                print("Error fetching models for \(config.name): \(error.localizedDescription)")
            }
        }
        
        let modelsAfterFiltering = newModels.filter { !incompatibleModels.contains($0.modelEntry.id) }  
        print("\nRefresh complete. Total models: \(modelsAfterFiltering.count), after removing incompatible models: \(modelsAfterFiltering.count)")
        newModels = modelsAfterFiltering
        let task = Task { @MainActor [newModels] in
            models = newModels
            await updateEnabledDisabledModels()
            isRefreshing = false
        }
        let _ = await task.value
    }
    
    private func updateEnabledDisabledModels() async {
        let disabledModelIds = self.disabledModelIds
        let task = Task { @MainActor in
            enabledModels = models.filter { !disabledModelIds.contains($0.id) }
            disabledModels = models.filter { disabledModelIds.contains($0.id) }
        }
        let _ = await task.value
    }
    
    func toggleModel(_ model: LLMModel) {
        if disabledModelIds.contains(model.id) {
            disabledModelIds.remove(model.id)
        } else {
            disabledModelIds.insert(model.id)
        }
        Task { await updateEnabledDisabledModels() }
    }
} 

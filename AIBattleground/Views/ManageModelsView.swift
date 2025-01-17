import Foundation
import SwiftUI

struct ManageModelsView: View {
    @EnvironmentObject private var serviceManager: LLMServiceManager
    @EnvironmentObject private var modelManager: LLMModelManager
    @State private var isRefreshing = false
    @State private var searchText = ""

    private var filteredEnabledModels: [LLMModel] {
        filterModels(modelManager.enabledModels)
    }

    private var filteredDisabledModels: [LLMModel] {
        filterModels(modelManager.disabledModels)
    }

    private func filterModels(_ models: [LLMModel]) -> [LLMModel] {
        if searchText.isEmpty {
            return models
        }

        let searchTerms = searchText.lowercased().split(separator: " ")
        return models.filter { model in
            // Model must match all search terms
            searchTerms.allSatisfy { term in
                // Search in model name
                if (model.modelEntry.displayName ?? model.modelEntry.id).lowercased().contains(term)
                {
                    return true
                }
                // Search in model ID
                if model.id.lowercased().contains(term) {
                    return true
                }
                // Search in model identifier
                if model.modelEntry.id.lowercased().contains(term) {
                    return true
                }
                // Search in provider name
                if model.configuration.protocolDriver.displayName.lowercased().contains(term) {
                    return true
                }
                // Search in configuration name
                if model.configuration.name.lowercased().contains(term) {
                    return true
                }
                // Search in comment if present
                if let comment = model.configuration.comment?.lowercased(),
                    comment.contains(term)
                {
                    return true
                }
                // Search in endpoint URL
                if model.configuration.endpointURL.absoluteString.lowercased().contains(term) {
                    return true
                }
                return false
            }
        }
    }

    var body: some View {
        List {
            Section("Actions") {
                Button {
                    Task {
                        await modelManager.refreshAvailableModels(for: serviceManager.services)
                    }
                } label: {
                    if modelManager.isRefreshing {
                        Label("Refreshing...", systemImage: "arrow.clockwise.circle")
                            .symbolEffect(.bounce, value: modelManager.isRefreshing)
                    } else {
                        Label("Refresh Models", systemImage: "arrow.clockwise.circle")
                    }
                }
                .disabled(modelManager.isRefreshing)
            }

            if !modelManager.serviceErrors.isEmpty {
                Section("Issues") {
                    ForEach(modelManager.serviceErrors, id: \.service.id) { serviceError in
                        HStack {
                            if let imageURL = serviceError.service.thumbnailImageURL {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable()
                                } placeholder: {
                                    Color.gray
                                }
                                .frame(width: 24, height: 24)
                            }

                            VStack(alignment: .leading) {
                                Text(serviceError.service.name)
                                    .font(.headline)
                                Text(serviceError.error.localizedDescription)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                }
            }

            Section("Enabled Models (\(filteredEnabledModels.count))") {
                if modelManager.enabledModels.isEmpty {
                    Label("No models have been enabled", systemImage: "xmark.circle")
                        .foregroundStyle(.red)
                } else if filteredEnabledModels.isEmpty {
                    Text("No enabled models match your search")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(filteredEnabledModels) { model in
                        ModelRow(
                            model: model,
                            isEnabled: true,
                            onToggle: { Task { await modelManager.toggleModel(model) } }
                        )
                    }
                }
            }

            Section("Disabled Models (\(filteredDisabledModels.count))") {
                if modelManager.disabledModels.isEmpty {
                    Text("No models have been disabled")
                        .foregroundStyle(.secondary)
                        .italic()
                } else if filteredDisabledModels.isEmpty {
                    Text("No disabled models match your search")
                        .foregroundStyle(.secondary)
                        .italic()
                } else {
                    ForEach(filteredDisabledModels) { model in
                        ModelRow(
                            model: model,
                            isEnabled: false,
                            onToggle: { Task { await modelManager.toggleModel(model) } }
                        )
                    }
                }
            }
        }
        .navigationTitle("Models")
        .onAppear {
//            print("*** models... \(modelManager.models)")
//            print("*** services... \(LLMServiceManager.shared.services)")
        }
        .onSubmit(of: .search) {
            // Handle search submit if needed
        }
        .onExitCommand {  // Handle Esc key
            searchText = ""
        }
    }
}

private struct ModelRow: View {
    let model: LLMModel
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            HStack(alignment: .center) {
                Group {
                    if let imageURL = model.configuration.thumbnailImageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 24, height: 24)
                    }

                    Text(model.modelEntry.displayName ?? model.modelEntry.id)
                        .font(.headline)
                    Text("(\(model.modelEntry.id))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("@ \(model.configuration.name)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let comment = model.configuration.comment, !comment.isEmpty {
                        Text("(\(comment))")
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button(isEnabled ? "Disable" : "Enable") {
                    onToggle()
                }
                .buttonStyle(.borderless)
                .foregroundStyle(isEnabled ? .red : .green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

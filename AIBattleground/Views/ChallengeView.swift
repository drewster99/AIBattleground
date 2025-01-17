import Foundation
import SwiftUI

struct ChallengeView: View {
    @EnvironmentObject private var modelManager: LLMModelManager
    @AppStorage("selected_model_ids") private var selectedModelIdsStorage: String = ""
    @AppStorage("last_challenge_prompt") private var prompt: String = ""
    @State private var selectedModelIds: Set<String> = []
    @State private var responses: [String: LLMResponse] = [:]
    @State private var errors: [String: Error] = [:]
    @State private var isQuerying = false
    @State private var showingModelSelection = false

    private func saveSelectedModels() {
        selectedModelIdsStorage = Array(selectedModelIds).joined(separator: ",")
    }

    private func loadSelectedModels() {
        let savedIds = Set(selectedModelIdsStorage.split(separator: ",").map(String.init))
        let enabledIds = Set(modelManager.enabledModels.map(\.id))
        selectedModelIds = savedIds.intersection(enabledIds)

        // Only if we have no valid selections AND we have enabled models,
        // default to first model per provider
        if selectedModelIds.isEmpty && !modelManager.enabledModels.isEmpty {
            let firstModelsByProvider = Dictionary(
                grouping: modelManager.enabledModels,
                by: { $0.configuration.protocolDriver.id }
            ).mapValues { $0.first }.values.compactMap { $0 }

            selectedModelIds = Set(firstModelsByProvider.map(\.id))
            saveSelectedModels()
        }
    }

    var selectedModelsPreview: String {
        let selectedModels = modelManager.models.filter { selectedModelIds.contains($0.id) }
        if selectedModels.isEmpty {
            return "No models selected"
        }

        if selectedModels.count <= 2 {
            return selectedModels.map { $0.modelSettings.name }.joined(separator: ", ")
        }

        let firstTwo = selectedModels.prefix(2).map { $0.modelSettings.name }.joined(separator: ", ")
        return "\(firstTwo) + \(selectedModels.count - 2) more"
    }

    var body: some View {
        List {
            Section("Selected Models") {
                Button {
                    showingModelSelection = true
                } label: {
                    HStack {
                        Label(selectedModelsPreview, systemImage: "checklist")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            PromptSection(
                prompt: $prompt,
                isQuerying: isQuerying,
                isSubmitDisabled: isQuerying || prompt.isEmpty || selectedModelIds.isEmpty,
                onSubmit: { Task { await submitChallenge() } }
            )

            if !responses.isEmpty || !errors.isEmpty {
                ResultsSection(
                    models: modelManager.models.filter { selectedModelIds.contains($0.id) },
                    responses: responses,
                    errors: errors,
                    onDeselect: { modelId in
                        selectedModelIds.remove(modelId)
                        saveSelectedModels()
                    },
                    onRetry: { model in
                        Task {
                            print("Retrying query for \(model.modelSettings.name)...")
                            responses[model.id] = nil
                            errors[model.id] = nil
                            let service = model.configuration.protocolDriver.serviceType.init(
                                configuration: model.configuration
                            )
                            
                            do {
                                let response = try await service.sendMessage([LLMMessage(role: .user, content: prompt)], modelProfile: model.modelProfile)
                                print("Received response from \(model.modelSettings.name)")
                                responses[model.id] = response
                                errors.removeValue(forKey: model.id)
                            } catch {
                                print("Error from \(model.modelSettings.name): \(error.localizedDescription) [\(error)]")
                                errors[model.id] = error
                            }
                        }
                    }
                )
            }
        }
        .navigationTitle("Challenge")
        .sheet(isPresented: $showingModelSelection) {
            NavigationStack {
                ModelSelectionView(
                    models: modelManager.enabledModels,
                    selectedIds: $selectedModelIds,
                    onSelectionChanged: { saveSelectedModels() }
                )
                .navigationTitle("Select Models")
                #if !os(macOS)
                    .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingModelSelection = false
                        }
                    }
                }
                .frame(minWidth: 400)
                .frame(height: 700)
            }
            #if !os(macOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            #endif
        }
        .onAppear {
            loadSelectedModels()
        }
        .onChange(of: modelManager.enabledModels) { old, new in
            let savedIds = Set(selectedModelIdsStorage.split(separator: ",").map(String.init))
            let enabledIds = Set(new.map(\.id))
            selectedModelIds = savedIds.intersection(enabledIds)

            // Only set defaults if we have no valid selections
            if selectedModelIds.isEmpty && !new.isEmpty {
                let firstModelsByProvider = Dictionary(
                    grouping: new,
                    by: { $0.configuration.protocolDriver.id }
                ).mapValues { $0.first }.values.compactMap { $0 }

                selectedModelIds = Set(firstModelsByProvider.map(\.id))
                saveSelectedModels()
            }
        }
    }

    private func submitChallenge() async {
        print("\n=== Starting Challenge ===")
        print("Prompt: \(prompt)")
        print("Selected Models: \(selectedModelIds.count)")

        isQuerying = true
        responses.removeAll()
        errors.removeAll()

        let selectedModels = modelManager.models.filter { selectedModelIds.contains($0.id) }
        print("Querying models:")
        selectedModels.forEach { model in
            print("- \(model.configuration.name): \(model.modelSettings.name)")
        }

        let messages = [LLMMessage(role: .user, content: prompt)]

        await withTaskGroup(of: (String, Result<LLMResponse, Error>).self) { group in
            for model in selectedModels {
                group.addTask {
                    print("Starting query for \(model.modelSettings.name)...")
                    let service = model.configuration.protocolDriver.serviceType.init(
                        configuration: model.configuration
                    )

                    do {
                        let response = try await service.sendMessage(messages, modelProfile: model.modelProfile)
                        print("Received response from \(model.modelSettings.name)")
                        return (model.id, .success(response))
                    } catch {
                        print("Error from \(model.modelSettings.name): \(error.localizedDescription) [\(error)]")
                        return (model.id, .failure(error))
                    }
                }
            }

            for await (modelId, result) in group {
                let model = selectedModels.first(where: { $0.id == modelId })!
                switch result {
                case .success(let response):
                    print("Storing response from \(model.modelSettings.name)")
                    responses[modelId] = response
                case .failure(let error):
                    print(
                        "Storing error from \(model.modelSettings.name): \(error.localizedDescription)")
                    errors[modelId] = error
                }
            }
        }

        print("\nChallenge complete")
        print("Successful responses: \(responses.count)")
        print("Errors: \(errors.count)")
        isQuerying = false
    }
}

private struct PromptSection: View {
    @Binding var prompt: String
    let isQuerying: Bool
    let isSubmitDisabled: Bool
    let onSubmit: () -> Void

    var body: some View {
        Section("Prompt") {
            VStack(alignment: .leading) {
                ResizableTextEditor(text: $prompt)

                Button(action: onSubmit) {
                    if isQuerying {
                        Label("Querying Models...", systemImage: "arrow.triangle.2.circlepath")
                            .symbolEffect(.bounce, value: isQuerying)
                    } else {
                        Label("Submit Challenge", systemImage: "paperplane.fill")
                    }
                }
                .disabled(isSubmitDisabled)
            }
        }
    }
}

private struct ResizableTextEditor: View {
    @Binding var text: String
    @State private var height: CGFloat = 44  // Height of 2 lines (~22pt per line)
    @State private var isDragging = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                TextEditor(text: $text)
                    .frame(height: height)
                
                // Bottom resize area
                Color.clear
                    .frame(height: 8)
                    .contentShape(Rectangle())
                    .onHover { inside in
                        if inside {
                            NSCursor.resizeUpDown.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                isDragging = true
                                height = max(44, height + value.translation.height)
                            }
                            .onEnded { _ in
                                isDragging = false
                            }
                    )
            }
            
            // Corner resize handle
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 8))
                .foregroundStyle(.secondary.opacity(0.6))
                .contentShape(Rectangle())
                .padding(.bottom, 8)
                .onHover { inside in
                    if inside {
                        NSCursor.resizeUpDown.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            height = max(44, height + value.translation.height)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ModelSelectionView: View {
    let models: [LLMModel]
    @Binding var selectedIds: Set<String>
    let onSelectionChanged: () -> Void
    @State private var searchText = ""

    private var filteredModels: [LLMModel] {
        if searchText.isEmpty {
            return models
        }

        let searchTerms = searchText.lowercased().split(separator: " ")
        return models.filter { model in
            // Model must match all search terms
            searchTerms.allSatisfy { term in
                // Search in model name
                if let displayName = model.modelEntry.displayName, displayName.lowercased().contains(term) {
                    return true
                }
                // Search in model ID
                if model.modelEntry.id.lowercased().contains(term) {
                    return true
                }
                // Search in provider name
                if model.configuration.protocolDriver.displayName.lowercased().contains(term) {
                    return true
                }
                // Search in comment if present
                if let comment = model.modelSettings.comment?.lowercased(),
                    comment.contains(term)
                {
                    return true
                }
                return false
            }
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search models...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding()

                if !searchText.isEmpty {
                    Text("Showing \(filteredModels.count) available models")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                }

                Divider()

                if !filteredModels.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            if Set(filteredModels.map(\.id)).isSubset(of: selectedIds) {
                                // If all filtered models are selected, deselect them
                                filteredModels.forEach { model in
                                    selectedIds.remove(model.id)
                                }
                            } else {
                                // Otherwise select all filtered models
                                filteredModels.forEach { model in
                                    selectedIds.insert(model.id)
                                }
                            }
                            onSelectionChanged()
                        } label: {
                            Text(
                                Set(filteredModels.map(\.id)).isSubset(of: selectedIds)
                                    ? "Deselect All" : "Select All"
                            )
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .padding()
                    }

                    Divider()
                }

                ForEach(filteredModels) { model in
                    ModelSelectionRow(
                        model: model,
                        isSelected: selectedIds.contains(model.id),
                        onToggle: { isSelected in
                            if isSelected {
                                selectedIds.insert(model.id)
                            } else {
                                selectedIds.remove(model.id)
                            }
                            onSelectionChanged()
                        }
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    if model.id != filteredModels.last?.id {
                        Divider()
                    }
                }

                if filteredModels.isEmpty {
                    Text("No models match your search")
                        .foregroundStyle(.secondary)
                        .italic()
                        .padding()
                }
            }
        }
        .background(.ultraThinMaterial)
    }
}

private struct ModelSelectionRow: View {
    let model: LLMModel
    let isSelected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            if let imageURL = model.configuration.thumbnailImageURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable()
                } placeholder: {
                    Color.gray
                }
                .frame(width: 24, height: 24)
            }

            VStack(alignment: .leading) {
                Text(model.modelSettings.name)
                    .font(.headline)
                Text(model.configuration.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle(
                "",
                isOn: Binding(
                    get: { isSelected },
                    set: onToggle
                ))
        }
    }
}

private struct ResultRow: View {
    let model: LLMModel
    let response: String?
    let error: Error?
    let onDeselect: (() -> Void)?
    let onRetry: (() -> Void)?
    @State private var isHovering = false
    @State private var showingCopied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let imageURL = model.configuration.thumbnailImageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable()
                    } placeholder: {
                        Color.gray
                    }
                    .frame(width: 24, height: 24)
                }
                
                Text(model.modelSettings.name)
                    .font(.headline)
                if error != nil || isHovering {
                    Button(action: { onRetry?() }) {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(error == nil ? Color.secondary : .red)
                }
                Spacer()
                
                if error != nil || isHovering {
                    HStack(spacing: 12) {
                        Button("Deselect", role: .destructive) {
                            onDeselect?()
                        }
                        .buttonStyle(.borderless)
                        .opacity(error != nil ? 1 : 0.75)
                    }
                }
            }
            
            if let error = error {
                HStack(alignment: .bottom) {
                    Text(error.localizedDescription)
                        .foregroundStyle(.red)
                    
                    Spacer()
                    
                    if isHovering {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(error.localizedDescription, forType: .string)
                            showingCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingCopied = false
                            }
                        } label: {
                            if showingCopied {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .onHover { hovering in
                            if hovering && !showingCopied {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            } else if let response = response {
                HStack(alignment: .bottom) {
                    Text(response)
                        .textSelection(.enabled)
                    
                    Spacer()
                    
                    if isHovering {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(response, forType: .string)
                            showingCopied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showingCopied = false
                            }
                        } label: {
                            if showingCopied {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .labelStyle(.iconOnly)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.borderless)
                        .onHover { hovering in
                            if hovering && !showingCopied {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
            if !hovering {
                NSCursor.pop()
            }
        }
    }
}

private struct ResultsSection: View {
    let models: [LLMModel]
    let responses: [String: LLMResponse]
    let errors: [String: Error]
    let onDeselect: (String) -> Void
    let onRetry: (LLMModel) -> Void

    private var modelsWithErrors: [LLMModel] {
        models.filter { errors[$0.id] != nil }
    }

    var body: some View {
        Group {
            Section("Results") {
                if models.isEmpty {
                    Text("No models selected")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(models) { model in
                        ResultRow(
                            model: model,
                            response: responses[model.id]?.message.content,
                            error: errors[model.id],
                            onDeselect: errors[model.id] != nil ? { onDeselect(model.id) } : nil,
                            onRetry: { onRetry(model) }
                        )
                    }
                }
            }

            if !modelsWithErrors.isEmpty {
                Section("Options") {
                    Button(role: .destructive) {
                        modelsWithErrors.forEach { model in
                            onDeselect(model.id)
                        }
                    } label: {
                        Label("Deselect All Failed Models", systemImage: "xmark.circle")
                    }
                }
            }
        }
    }
}

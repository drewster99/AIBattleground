import Foundation
import SwiftUI

struct ManageServicesView: View {
    @EnvironmentObject private var serviceManager: LLMServiceManager
    @State private var showingAddSheet = false
    @State private var serviceForEditing: LLMServiceConfiguration?
    @State private var showingDeleteConfirmation = false
    @State private var serviceToDelete: LLMServiceConfiguration?
    @State private var selectedService: LLMServiceConfiguration?

    var body: some View {
        List(selection: $selectedService) {
            Section {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Add Service", systemImage: "plus")
                }
                .padding(.bottom, 12)
            }

            ForEach(serviceManager.services) { service in
                ServiceRow(
                    service: service,
                    selectedService: $selectedService,
                    onEdit: { serviceForEditing = service }
                )
                .contentShape(Rectangle())
                .tag(service)
            }
        }
        .navigationTitle("Services")
        .sheet(isPresented: $showingAddSheet) {
            NavigationStack {
                CredentialSheet(
                    mode: .add,
                    onSave: { showingAddSheet = false }
                )
                .navigationTitle("Add Service")
#if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
            }
            .frame(minWidth: 800, minHeight: 900)
        }
        .sheet(item: $serviceForEditing, onDismiss: { selectedService = nil }) { service in
            NavigationStack {
                CredentialSheet(
                    mode: .edit(service),
                    onSave: {
                        serviceForEditing = nil
                    }
                )
                .navigationTitle("Edit Service")
#if !os(macOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
            }
            .frame(width: 800, height: 900)
        }
        .alert("Delete Service?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let service = serviceToDelete {
                    Task {
                        try await serviceManager.delete(service)
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let service = serviceToDelete {
                Text("Are you sure you want to delete '\(service.name)'? This cannot be undone.")
            }
        }
    }
}

private struct ServiceRow: View {
    let service: LLMServiceConfiguration
    @Binding var selectedService: LLMServiceConfiguration?
    let onEdit: () -> Void
    @State private var isValidating = false
    @State private var validationError: Error?

    var isSelected: Bool {
        selectedService?.id == service.id
    }
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    if let imageURL = service.thumbnailImageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable()
                        } placeholder: {
                            Color.gray
                        }
                        .frame(width: 24, height: 24)
                    }
                    Text(service.name)
                        .font(.title2)
                }

                HStack {
                    Color.clear
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        if let comment = service.comment {
                            if !comment.isEmpty {
                                Text(comment)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if isSelected {
                            if !service.endpointURL.absoluteString.isEmpty {
                                Text(service.endpointURL.absoluteString)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                + Text(" (\(service.protocolDriver.displayName))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Last Updated: \(service.lastUpdate.formatted())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            Spacer()

            Group {
                if let error = validationError {
                    if service.lastUpdate == .distantPast {
                        Button {
                            onEdit()
                        } label: {
                            Text("Add credentials")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .trailing) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                                Text("Needs attention")
                                    .foregroundStyle(.red)
                            }
                            Text(error.localizedDescription)
                                .foregroundStyle(.red)
                        }
                    }
                } else if isValidating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    if !isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                if isSelected && !isValidating && validationError == nil {
                    Button("Edit") {
                        onEdit()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.top, 4)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .onAppear {
            validateService(service)
        }
        .onChange(of: service) { _, new in
            print("changed **** service! ***")
            validateService(new)
        }
        .onChange(of: (isSelected && !isValidating && validationError != nil && service.lastUpdate != .distantPast)) { _, shouldEdit in
            if shouldEdit {
                print("editing because of change shouldEdit")
                onEdit()
            }
        }
    }

    private func validateService(_ service: LLMServiceConfiguration) {
        isValidating = true
        validationError = nil

        let service = service.protocolDriver.serviceType.init(configuration: service)

        service.getAvailableModels { result in
            isValidating = false
            switch result {
            case .success:
                break
            case .failure(let error):
                validationError = error
            }

        }
    }
}

//
//  DebugCredentialsView.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/14/25.
//

import Foundation
import SwiftUI

#if DEBUG
struct DebugServicesView: View {
    @EnvironmentObject private var credentialManager: LLMCredentialKeyManager
    @EnvironmentObject private var servicesManager: LLMServiceManager
    @State private var result: String?
    @State private var showingDeleteConfirmation = false

    var services: [LLMServiceConfiguration] {
        servicesManager.services
    }
    
    private func displayValue(_ value: String?) -> some View {
        if let value {
            if value.isEmpty {
                Text("empty string")
                    .foregroundStyle(.red)
            } else {
                Text(value)
            }
        } else {
            Text("<nil>")
                .foregroundStyle(.secondary)
        }
    }

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All", systemImage: "trash")
                }
            }

            if !services.isEmpty {
                Section("LLM Services") {
                    ForEach(services) { service in
                        VStack(alignment: .leading, spacing: 4) {
                            Group {
                                HStack {
                                    Text("Name: ")
                                    displayValue(service.name)
                                }
                                HStack {
                                    Text("ID: ")
                                    displayValue(service.id)
                                }
                                HStack {
                                    Text("Protocol provider: ")
                                    displayValue(service.protocolDriver.displayName)
                                }
                                HStack {
                                    Text("API Key: ")
                                    displayValue(service.apiKey)
                                }
                                HStack {
                                    Text("Username: ")
                                    displayValue(service.username)
                                }
                                HStack {
                                    Text("Comment: ")
                                    displayValue(service.comment)
                                }
                                Text("Last Updated: \(service.lastUpdate.formatted(.iso8601))")
                            }
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if let result {
                Section("Result") {
                    Text(result)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Debug Services")
        .alert("Delete All Services?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { try await LLMServiceManager.shared.deleteAllServices() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete all services? This cannot be undone.")
        }
    }
}
#endif

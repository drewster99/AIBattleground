//
//  LLMServiceManager.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/13/25.
//

import Foundation
import SwiftUI

actor LLMServiceManager: ObservableObject {
    public static let shared = LLMServiceManager()

    private let defaults = UserDefaults.standard
    private let servicesKey = "llm_service_configurations"
    private var p_services: [LLMServiceConfiguration] = [] {
        didSet {
            DispatchQueue.main.async { [p_services] in
                self.services = p_services
            }
        }
    }
    private var didDoDeferredInit: Bool = false

    @MainActor @Published public private(set) var services: [LLMServiceConfiguration] = []

#if DEBUG
    public func deleteAllServices() async throws {
        try deferredInit()
        for service in p_services {
            try await service.setApiKey(nil)
        }
        p_services = []
        try saveServices()
        didDoDeferredInit = false
        try deferredInit()
    }
#endif

    public func add(_ service: LLMServiceConfiguration) throws {
        try deferredInit()
        guard !p_services.contains(where: { $0.id == service.id }) else {
            try update(service)
            return
        }
        p_services.append(service)
        try saveServices()
    }

    public func delete(_ service: LLMServiceConfiguration) async throws {
        try deferredInit()
        p_services.removeAll { $0.id == service.id }
        try saveServices()
        try await service.setApiKey(nil)
    }

    public func getService(id: LLMServiceConfiguration.ID) throws -> LLMServiceConfiguration? {
        try deferredInit()
        let service = p_services.first { $0.id == id }
        return service
    }

    public func update(_ service: LLMServiceConfiguration) throws {
        try deferredInit()
        if let index = p_services.firstIndex(where: { $0.id == service.id }) {
            p_services[index] = service
        } else {
            fatalError("Can't update non-existent index")
        }
        try saveServices()
    }

    private init() {
        Task { try await deferredInit() }
    }

    private func deferredInit() throws {
        guard !didDoDeferredInit else { return }
        didDoDeferredInit = true

        if let data = defaults.data(forKey: servicesKey) {
            try loadServices(from: data)
        } else {
            try saveServices()
        }
    }

    private func loadServices(from data: Data) throws {
        do {
            let loadedServices = try JSONDecoder().decode([LLMServiceConfiguration].self, from: data)
            var services: [LLMServiceConfiguration] = []

            var needsSaving = false
            for service in LLMServiceConfiguration.defaultServiceConfigurations {
                if let existingLoadedService = loadedServices.first(where: { $0.id == service.id }) {
                    services.append(existingLoadedService)
                } else {
                    services.append(service)
                    needsSaving = true
                }
            }

            for loadedService in loadedServices {
                if !services.contains(where: { $0.id == loadedService.id }) {
                    services.append(loadedService)
                }
            }

            p_services = services
            if needsSaving {
                try saveServices()
            }
        } catch {
            throw LLMServiceError.decodingError(error)
        }
    }

    private func saveServices() throws {
        do {
            let data = try JSONEncoder().encode(p_services)
            defaults.set(data, forKey: servicesKey)
        } catch {
            throw LLMServiceError.encodingError(error)
        }
    }
}

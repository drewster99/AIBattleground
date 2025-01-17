//
//  AIBattlegroundApp.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/8/25.
//

import Foundation
import SwiftUI

@main
struct AIBattlegroundApp: App {
    @StateObject private var credentialManager = LLMCredentialKeyManager.shared
    @StateObject private var modelManager = LLMModelManager.shared
    @StateObject private var serviceManager = LLMServiceManager.shared

    init() {

        // Set  ram cache
        let cacheSizeMemory = 128 * 1024 * 1024  // 128 MB

        // Set disk cache
        let cacheSizeDisk = 256 * 1024 * 1024  // 256 MB

        // Set up a new shared cache
        URLCache.shared = URLCache(
            memoryCapacity: cacheSizeMemory, diskCapacity: cacheSizeDisk, diskPath: nil)

        // URLSession.shared.configuration.requestCachePolicy = .reloadRevalidatingCacheData
        URLSession.shared.configuration.urlCache = URLCache.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    await modelManager.refreshAvailableModels(for: serviceManager.services)
                }
                .onChange(of: serviceManager.services) { old, new in
                    Task { await modelManager.refreshAvailableModels(for: new) }
                }
                .environmentObject(credentialManager)
                .environmentObject(serviceManager)
                .environmentObject(modelManager)
        }
    }
}

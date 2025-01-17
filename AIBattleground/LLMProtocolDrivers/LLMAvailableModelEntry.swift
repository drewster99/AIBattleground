//
//  LLMAvailableModelEntry.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/14/25.
//

import Foundation
import SwiftUI

/// A model entry for a given LLM service provider.
struct LLMAvailableModelEntry: Codable, Identifiable, Hashable, Equatable {
    let id: String           // Raw model identifier
    let displayName: String? // Human-readable name
    let provider: String     // e.g., "OpenAI", "Anthropic"
    let created: Date?       // When the model was released
    let description: String? // Optional model description
}

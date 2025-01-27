//
//  PromptMessage.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/26/25.
//

import Foundation

struct PromptMessage: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    var role: LLMMessage.MessageRole
    var text: String
    var variableReplacements: [VariableReplacement]
}

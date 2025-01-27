//
//  PromptVariable.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/26/25.
//

import Foundation

struct PromptVariable: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let variableType: PromptVariableType
}

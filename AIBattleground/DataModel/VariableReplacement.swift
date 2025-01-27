//
//  VariableReplacement.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/26/25.
//

import Foundation

struct VariableReplacement: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    let variable: PromptVariable
    var insertionPoint: Int
}

//
//  PromptChain.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/26/25.
//

import Foundation

struct PromptChain: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var promptMessages: [PromptMessage]
}

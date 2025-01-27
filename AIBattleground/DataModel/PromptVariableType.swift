//
//  PromptVariableType.swift
//  AIBattleground
//
//  Created by Andrew Benson on 1/26/25.
//


enum PromptVariableType: Identifiable, Equatable, Codable, Hashable {
    typealias ID = String
    
    case string

    var id: ID {
        switch self {
        case .string: "string"
        }
    }
}

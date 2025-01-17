import Foundation
import Security
import SwiftUI

actor LLMCredentialKeyManager: ObservableObject {
    public static let shared = LLMCredentialKeyManager()
    private init() {}
    private let keychainGroup = "P8MA38JTXY.com.nuclearcyborg.AIBattleground.shared"

   // MARK: PUBLIC INTERFACE

    private var apiKeyCache: [LLMServiceConfiguration.ID: String] = [:]

    public func getApiKey(credentialID: LLMServiceConfiguration.ID) -> String? {
        do {
            if let apiKey = apiKeyCache[credentialID] {
                return apiKey
            }
            let apiKey = try getApiKey(for: credentialID)
            apiKeyCache[credentialID] = apiKey
            return apiKey
        } catch {
            return nil
        }
    }

    nonisolated public func getApiKeySynchronously(credentialID: LLMServiceConfiguration.ID?) -> String? {
        guard let credentialID else { return nil }
        var result: String? = nil

        let dg = DispatchGroup()
        dg.enter()
        Task {
            result = await self.getApiKey(credentialID: credentialID)
            dg.leave()
        }
        dg.wait()
        
        return result
    }

    /// Fetches the API key from secure storage for a given credential
    public func getApiKey(_ credential: LLMServiceConfiguration) -> String? {
        getApiKey(credentialID: credential.id)
    }

    /// Updates an existing apiKey for the given credential, or creates a new one if that one doesn't exist
    /// Setting a new value of `nil` deletes the key, if it exists already
    public func setApiKey(_ apiKey: String?, credentialID: LLMServiceConfiguration.ID) async throws {
        guard let apiKey else {
            do {
                try deleteApiKey(for: credentialID)
                apiKeyCache.removeValue(forKey: credentialID)
            } catch {
                print("warning: error trying to delete apiKey for credential \(credentialID): \(error)")
            }
            return
        }

        do {
            _ = try getApiKey(for: credentialID)
            // if we were able to read it, then it exists already, so update, right?
            try updateApiKey(apiKey, for: credentialID)
        } catch {
            try saveApiKey(apiKey, for: credentialID)
        }
        apiKeyCache[credentialID] = apiKey
    }


    // MARK: - Keychain Operations

    private func saveApiKey(_ apiKey: String, for credentialID: LLMServiceConfiguration.ID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialID,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessGroup as String: keychainGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
            
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status != errSecDuplicateItem else {
            try updateApiKey(apiKey, for: credentialID)
            return
        }

        guard status == errSecSuccess else {
            throw LLMCredentialError.keychainError(status: status)
        }
    }

    private func updateApiKey(_ apiKey: String, for credentialID: LLMServiceConfiguration.ID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialID,
            kSecAttrAccessGroup as String: keychainGroup,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: apiKey.data(using: .utf8)!
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw LLMCredentialError.keychainError(status: status)
        }
    }

    private func getApiKey(for credentialID: LLMServiceConfiguration.ID) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialID,
            kSecReturnData as String: true,
            kSecAttrAccessGroup as String: keychainGroup
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
            let data = result as? Data,
            let apiKey = String(data: data, encoding: .utf8)
        else {
            throw LLMCredentialError.apiKeyNotFound
        }

        return apiKey
    }

    private func deleteApiKey(for credentialID: LLMServiceConfiguration.ID) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: credentialID,
            kSecAttrAccessGroup as String: keychainGroup
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw LLMCredentialError.keychainError(status: status)
        }
    }
}

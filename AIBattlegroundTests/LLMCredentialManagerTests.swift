import Foundation
@testable import AIBattleground
import Testing

@Suite("LLM Credential Manager Tests")
struct LLMCredentialKeyManagerTests {
    
    private func createManager() -> LLMCredentialKeyManager {
        LLMCredentialKeyManager.shared
    }
    
    @Test("Create Credential")
    func testCreateCredential() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║             CREDENTIAL TEST: CREATE CREDENTIAL               ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
        
        let manager = LLMCredentialKeyManager.shared
        let credential = try await manager.createCredential(
            llmServiceID: "test-service",
            apiKey: "test-key-123",
            username: "test-user",
            comment: "Test credential"
        )
        
        print("Created credential:")
        print("ID: \(credential.id)")
        print("Service ID: \(credential.llmServiceID)")
        print("Username: \(credential.username ?? "<nil>")")
        print("Comment: \(credential.comment ?? "<nil>")")
        print("API Key: \(credential.apiKey)")
        
        #expect(credential.llmServiceID == "test-service")
        #expect(credential.apiKey == "test-key-123")
        #expect(credential.username == "test-user")
        #expect(credential.comment == "Test credential")
    }
    
    @Test("Update Credential")
    func testUpdateCredential() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║             CREDENTIAL TEST: UPDATE CREDENTIAL               ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
        
        let manager = LLMCredentialKeyManager.shared
        let credential = try await manager.createCredential(
            llmServiceID: "test-service",
            apiKey: "test-key-123"
        )
        
        print("Original credential API key: \(credential.apiKey)")
        
        let updatedCredential = credential.replacingApiKey("new-test-key-456")
        #expect(updatedCredential.id == credential.id, "Credential ID changed when replacingApiKey!")
        try await manager.updateCredential(updatedCredential)
        
        let retrieved = try await manager.getCredential(credential.id)
        print("Updated credential API key: \(retrieved.apiKey)")
        
        #expect(retrieved.apiKey == "new-test-key-456", "API key was not updated correctly")
        #expect(retrieved.id == credential.id, "Credential ID changed during update")
    }
    
    @Test("Delete Credential")
    func testDeleteCredential() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║             CREDENTIAL TEST: DELETE CREDENTIAL               ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
        
        let manager = LLMCredentialKeyManager.shared
        let credential = try await manager.createCredential(
            llmServiceID: "test-service",
            apiKey: "test-key-123"
        )
        
        print("Created credential with ID: \(credential.id)")
        try await manager.deleteCredential(credential)
        print("Deleted credential")
        
        do {
            _ = try await manager.getCredential(credential.id)
            throw LLMCredentialError.invalidCredential // Should not reach here
        } catch LLMCredentialError.credentialNotFound {
            print("Successfully verified credential was deleted")
        }
    }
} 

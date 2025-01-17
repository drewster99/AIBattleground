import Foundation
@testable import AIBattleground
import Testing

@Suite("Claude Tests")
struct ClaudeTests {
    let configuration = LLMServiceConfiguration(
        name: "Claude Test",
        comment: "Test configuration",
        lastUpdate: Date(),
        protocolDriver: .claude,
        endpointURL: URL(string: "https://api.anthropic.com/v1")!,
        thumbnailImageURL: URL(string: "https://anthropic.com/favicon.ico")!
    )

    let modelSettings = LLMModelSettings(
        id: UUID(),
        name: "claude 3.5 sonnet",
        comment: "Test settings"
    )

    @Test("Get Available Models")
    func testGetAvailableModels() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║                 CLAUDE TEST: GET MODELS                      ║
        ╚══════════════════════════════════════════════════════════════╝
        """)

        let service = ClaudeProtocolDriver(configuration: configuration)
        
        print("Fetching available Claude models...")
        try await withCheckedThrowingContinuation { continuation in
            service.getAvailableModels { result in
                switch result {
                case .success(let models):
                    print("\nAvailable Claude models:")
                    models.forEach { model in
                        print("- \(model.id) (\(model.displayName ?? "<nil>"))")
                        if let created = model.created {
                            print("  Released: \(created)")
                        }
                        if let description = model.description {
                            print("  Description: \(description)")
                        }
                    }
                    continuation.resume()
                case .failure(let error):
                    print("Error fetching models: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    @Test("Claude Chat")
    func testClaude() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║                   CLAUDE TEST: CHAT                          ║
        ╚══════════════════════════════════════════════════════════════╝
        """)
        
        let service = ClaudeProtocolDriver(configuration: configuration)
                let message = LLMMessage(role: .user, content: "Say hello!")
        print("Sending message to Claude: \(message.content)")
        let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "claude-3-5-sonnet-20241022",
                displayName: "Claude 3.5 Sonnet",
                provider: "Anthropic",
                created: Date(),
                description: "Most capable Claude model"
            ),
            modelSettings: modelSettings
        )
        
        let response = try await service.sendMessage([message], modelProfile: modelProfile)
        print("\nResponse details:")
        print("Message content: \(response.message.content)")
        print("Message role: \(response.message.role)")
        print("Total tokens: \(response.totalTokens ?? 0)")
        print("Prompt tokens: \(response.promptTokens ?? 0)")
        print("Completion tokens: \(response.completionTokens ?? 0)")
        print("Finish reason: \(response.finishReason ?? "none")")
        print("Is complete: \(response.isComplete)")
        print("Streamed content count: \(response.streamedContent.count)")
    }
    
    @Test("Claude Streaming")
    func testClaudeStreaming() async throws {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║                 CLAUDE TEST: STREAMING                       ║
        ╚══════════════════════════════════════════════════════════════╝
        """)

        let service = ClaudeProtocolDriver(configuration: configuration)
        let message = LLMMessage(role: .user, content: "Count slowly from 1 to 5")
         let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "claude-3-5-sonnet-20241022",
                displayName: "Claude 3.5 Sonnet",
                provider: "Anthropic",
                created: Date(),
                description: "Most capable Claude model"
            ),
            modelSettings: modelSettings
        )
        
        print("Sending streaming message to Claude: \(message.content)")
        try await withCheckedThrowingContinuation { continuation in
            service.streamMessage(
                [message],
                modelProfile: modelProfile,
                onReceive: { chunk in
                    print("Received chunk from Claude: \(chunk)")
                },
                onComplete: { result in
                    switch result {
                    case .success(let response):
                        print("\nClaude Stream complete!")
                        print("Final message: \(response.message.content)")
                        print("Streamed chunks: \(response.streamedContent.count)")
                        continuation.resume()
                    case .failure(let error):
                        print("Claude Stream error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }
} 

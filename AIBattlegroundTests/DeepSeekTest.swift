import Foundation
import Testing

@testable import AIBattleground

@Suite("DeepSeek Tests")
struct DeepSeekTests {
    let configuration = LLMServiceConfiguration(
        name: "DeepSeek Test",
        comment: "Test configuration",
        lastUpdate: Date(),
        protocolDriver: .openai,
        endpointURL: URL(string: "https://api.deepseek.com/v1")!,
        thumbnailImageURL: URL(string: "https://deepseek.com/favicon.ico")!
        // sk-9c2dcbebe94342eba2aea5eb3bb74eb4
    )

    let modelSettings = LLMModelSettings(
        id: UUID(),
        name: "deepseek-chat",
        comment: "Test settings"
    )

    @Test("DeepSeek Chat")
    func testDeepSeek() async throws {
        print(
            """

            ╔══════════════════════════════════════════════════════════════╗
            ║                  DeepSeek TEST: CHAT                         ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        let service = DeepSeekProtocolDriver(
            configuration: configuration
        )
        let message = LLMMessage(role: .user, content: "Say hello!")
        let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "deepseek-chat",
                displayName: "deepseek-chat",
                provider: "DeepSeek",
                created: Date(),
                description: "deepseek-chat"
            ),
            modelSettings: modelSettings
        )
        print("Sending message: \(message.content)")
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

    @Test("DeepSeek Streaming")
    func testDeepSeekStreaming() async throws {
        print(
            """

            ╔══════════════════════════════════════════════════════════════╗
            ║                DeepSeek TEST: STREAMING                      ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        let service = DeepSeekProtocolDriver(
            configuration: configuration
        )
        let message = LLMMessage(role: .user, content: "Count slowly from 1 to 5")
        let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "deepseek-chat",
                displayName: "deepseek-chat",
                provider: "DeepSeek",
                created: Date(),
                description: "deepseek-chat"
            ),
            modelSettings: modelSettings
        )
        print("Sending streaming message: \(message.content)")
        try await withCheckedThrowingContinuation { continuation in
            service.streamMessage(
                [message],
                modelProfile: modelProfile,
                onReceive: { chunk in
                    print("Received chunk: \(chunk)")
                },
                onComplete: { result in
                    switch result {
                    case .success(let response):
                        print("\nStream complete!")
                        print("Final message: \(response.message.content)")
                        print("Streamed chunks: \(response.streamedContent.count)")
                        continuation.resume()
                    case .failure(let error):
                        print("Stream error: \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            )
        }
    }

    @Test("Get Available Models")
    func testGetAvailableModels() async throws {
        print(
            """

            ╔══════════════════════════════════════════════════════════════╗
            ║                DeepSeek TEST: GET MODELS                     ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        let service = DeepSeekProtocolDriver(
            configuration: configuration
        )

        print("\nFetching available DeepSeek models...")
        try await withCheckedThrowingContinuation { continuation in
            service.getAvailableModels { result in
                switch result {
                case .success(let models):
                    print("\nAvailable DeepSeek models:")
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
}

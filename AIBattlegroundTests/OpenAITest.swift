import Foundation
import Testing

@testable import AIBattleground

@Suite("OpenAI Tests")
struct OpenAITests {
    let configuration = LLMServiceConfiguration(
        name: "OpenAI Test",
        comment: "Test configuration",
        lastUpdate: Date(),
        protocolDriver: .openai,
        endpointURL: URL(string: "https://api.openai.com/v1")!,
        thumbnailImageURL: URL(string: "https://openai.com/favicon.ico")!
    )

    let modelSettings = LLMModelSettings(
        id: UUID(),
        name: "gpt-3.5-turbo",
        comment: "Test settings"
    )

    @Test("OpenAI Chat")
    func testOpenAI() async throws {
        print(
            """

            ╔══════════════════════════════════════════════════════════════╗
            ║                   OPENAI TEST: CHAT                          ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        let service = OpenAIProtocolDriver(
            configuration: configuration
        )
        let message = LLMMessage(role: .user, content: "Say hello!")
        let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "gpt-3.5-turbo",
                displayName: "gpt-3.5-turbo",
                provider: "OpenAI",
                created: Date(),
                description: "gpt-3.5-turbo"
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

    @Test("OpenAI Streaming")
    func testOpenAIStreaming() async throws {
        print(
            """

            ╔══════════════════════════════════════════════════════════════╗
            ║                 OPENAI TEST: STREAMING                       ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        let service = OpenAIProtocolDriver(
            configuration: configuration
        )
        let message = LLMMessage(role: .user, content: "Count slowly from 1 to 5")
        let modelProfile = LLMModelProfile(
            modelEntry: LLMAvailableModelEntry(
                id: "gpt-3.5-turbo",
                displayName: "gpt-3.5-turbo",
                provider: "OpenAI",
                created: Date(),
                description: "gpt-3.5-turbo"
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
            ║                 OPENAI TEST: GET MODELS                      ║
            ╚══════════════════════════════════════════════════════════════╝
            """)

        print("\nFetching available OpenAI models...")
        let service = OpenAIProtocolDriver(
            configuration: configuration
        )

        print("\nFetching available OpenAI models...")
        try await withCheckedThrowingContinuation { continuation in
            service.getAvailableModels { result in
                switch result {
                case .success(let models):
                    print("\nAvailable OpenAI models:")
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

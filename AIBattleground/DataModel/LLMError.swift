import Foundation

enum LLMError: LocalizedError {
    case invalidEndpoint
    case networkError(Error)
    case invalidResponse
    case authenticationError
    case rateLimitExceeded
    case contextLengthExceeded
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "Invalid API endpoint"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationError:
            return "Invalid API key or authentication failed"
        case .rateLimitExceeded:
            return "Rate limit exceeded"
        case .contextLengthExceeded:
            return "Context length exceeded"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
} 
import Foundation

enum LLMCredentialError: LocalizedError {
    case credentialNotFound
    case apiKeyNotFound
    case invalidCredential
    case decodingError(Error)
    case encodingError(Error)
    case keychainError(status: OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .credentialNotFound:
            return "Credential not found"
        case .apiKeyNotFound:
            return "API key not found in keychain"
        case .invalidCredential:
            return "Invalid credential"
        case .decodingError(let error):
            return "Failed to decode credentials: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode credentials: \(error.localizedDescription)"
        case .keychainError(let status):
            return "Keychain error: \(keychainErrorString(for: status))"
        }
    }
    
    private func keychainErrorString(for status: OSStatus) -> String {
        switch status {
        case errSecDuplicateItem:
            return "A credential already exists for this service"
        case errSecItemNotFound:
            return "Credential not found in keychain"
        case errSecAuthFailed:
            return "Authentication failed"
        case errSecDecode:
            return "Failed to decode keychain item"
        case errSecParam:
            return "Invalid parameters provided"
        case errSecNotAvailable:
            return "Keychain is not available"
        case errSecUserCanceled:
            return "Operation cancelled by user"
        default:
            return "Unknown keychain error (code: \(status))"
        }
    }
} 
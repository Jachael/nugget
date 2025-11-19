import Foundation

struct CognitoConfig {
    static let userPoolId = "eu-west-1_1zILS9mOj"
    static let clientId = "6roa95ol200brl6tsrlnkckpd6"
    static let region = "eu-west-1"

    // For production, this should be set via environment or build configuration
    static let useCognito: Bool = {
        #if DEBUG
        // In debug mode, check for environment variable or default to false for local testing
        return ProcessInfo.processInfo.environment["USE_COGNITO"] == "true"
        #else
        // In release mode, always use Cognito
        return true
        #endif
    }()

    static var authEndpoint: String {
        return useCognito ? "/auth/cognito" : "/auth/apple"
    }
}
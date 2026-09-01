import AuthenticationServices
import Foundation

enum AuthError: Error, Equatable, Sendable {
    case cancelled
    case invalidEmail
    case passwordTooShort
    case emailAlreadyInUse
    case accountDisabled
    case invalidCredential
    case networkUnavailable
    case providerNotConfigured
    case providerUnavailable
    case unknown

    var shouldPresentMessage: Bool {
        self != .cancelled
    }

    var message: LocalizedStringResource {
        switch self {
        case .cancelled:
            "auth_error_cancelled"
        case .invalidEmail:
            "auth_error_invalid_email"
        case .passwordTooShort:
            "auth_error_password_too_short"
        case .emailAlreadyInUse:
            "auth_error_email_in_use"
        case .accountDisabled:
            "auth_error_account_disabled"
        case .invalidCredential:
            "auth_error_invalid_credential"
        case .networkUnavailable:
            "auth_error_network"
        case .providerNotConfigured:
            "auth_error_provider_not_configured"
        case .providerUnavailable:
            "auth_error_provider_unavailable"
        case .unknown:
            "auth_error_unknown"
        }
    }

    static func map(_ error: Error) -> AuthError {
        if let authError = error as? AuthError {
            return authError
        }

        let error = error as NSError
        if error.domain == ASAuthorizationError.errorDomain,
           error.code == ASAuthorizationError.canceled.rawValue {
            return .cancelled
        }

        if error.domain == "com.google.GIDSignIn", error.code == -5 {
            return .cancelled
        }

        if error.domain == NSURLErrorDomain {
            return .networkUnavailable
        }

        guard error.domain == "FIRAuthErrorDomain" else {
            return .unknown
        }

        return switch error.code {
        case 17004, 17009, 17094:
            .invalidCredential
        case 17005:
            .accountDisabled
        case 17006, 17028:
            .providerUnavailable
        case 17007, 17012:
            .emailAlreadyInUse
        case 17008:
            .invalidEmail
        case 17020, 17061:
            .networkUnavailable
        case 17026:
            .passwordTooShort
        case 17058:
            .cancelled
        default:
            .unknown
        }
    }
}

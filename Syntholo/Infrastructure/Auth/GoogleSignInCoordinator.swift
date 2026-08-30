import Foundation
@preconcurrency import GoogleSignIn
import UIKit

struct GoogleSignInConfiguration: Sendable, Equatable {
    static let missingValue = "syntholo-google-signin-not-configured"

    let clientID: String?
    let reversedClientScheme: String?

    var isConfigured: Bool {
        guard let clientID = Self.configuredValue(clientID),
              let reversedClientScheme = Self.configuredValue(
                reversedClientScheme
              ),
              clientID.hasSuffix(".apps.googleusercontent.com") else {
            return false
        }

        let suffix = ".apps.googleusercontent.com"
        let identifier = String(clientID.dropLast(suffix.count))
        return !identifier.isEmpty
            && reversedClientScheme
                == "com.googleusercontent.apps.\(identifier)"
    }

    @MainActor
    static var current: GoogleSignInConfiguration {
        GoogleSignInConfiguration(
            clientID: Bundle.main.object(
                forInfoDictionaryKey: "GIDClientID"
            ) as? String,
            reversedClientScheme: Bundle.main.object(
                forInfoDictionaryKey: "GIDReversedClientScheme"
            ) as? String
        )
    }

    private static func configuredValue(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ),
            !value.isEmpty,
            value != missingValue,
            !value.contains("$(") else {
            return nil
        }
        return value
    }
}

@MainActor
final class GoogleSignInCoordinator {
    private struct Tokens: Sendable {
        let idToken: String
        let accessToken: String
    }

    private let authClient: any AuthClient
    private let configuration: GoogleSignInConfiguration

    init(
        authClient: any AuthClient,
        configuration: GoogleSignInConfiguration = .current
    ) {
        self.authClient = authClient
        self.configuration = configuration
    }

    func signIn(
        presenting viewController: UIViewController
    ) async throws -> AuthenticatedUser {
        guard configuration.isConfigured,
              let clientID = configuration.clientID else {
            throw AuthError.providerNotConfigured
        }

        let signIn = GIDSignIn.sharedInstance
        signIn.configuration = GIDConfiguration(clientID: clientID)

        let tokens: Tokens
        do {
            tokens = try await withCheckedThrowingContinuation { continuation in
                signIn.signIn(withPresenting: viewController) { result, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let user = result?.user,
                          let idToken = user.idToken?.tokenString else {
                        continuation.resume(
                            throwing: AuthError.invalidCredential
                        )
                        return
                    }

                    continuation.resume(
                        returning: Tokens(
                            idToken: idToken,
                            accessToken: user.accessToken.tokenString
                        )
                    )
                }
            }
        } catch {
            throw AuthError.map(error)
        }

        return try await authClient.signInWithGoogle(
            idToken: tokens.idToken,
            accessToken: tokens.accessToken
        )
    }

    static func handle(_ url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }
}

import AuthenticationServices
import Foundation
import SwiftUI

@MainActor
final class AppleSignInCoordinator {
    private let authClient: any AuthClient
    private var rawNonce: String?
    private var preparationError: AuthError?

    init(authClient: any AuthClient) {
        self.authClient = authClient
    }

    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        do {
            let nonce = try AppleNonce.random()
            rawNonce = nonce
            preparationError = nil
            request.requestedScopes = [.fullName, .email]
            request.nonce = AppleNonce.sha256(nonce)
        } catch {
            rawNonce = nil
            preparationError = .providerUnavailable
        }
    }

    func complete(
        _ result: Result<ASAuthorization, Error>
    ) async throws -> AuthenticatedUser {
        if let preparationError {
            self.preparationError = nil
            throw preparationError
        }

        switch result {
        case let .failure(error):
            rawNonce = nil
            throw AuthError.map(error)
        case let .success(authorization):
            guard let credential = authorization.credential
                as? ASAuthorizationAppleIDCredential,
                let identityToken = credential.identityToken else {
                self.rawNonce = nil
                throw AuthError.invalidCredential
            }

            return try await complete(
                identityToken: identityToken,
                fullName: credential.fullName
            )
        }
    }

    func complete(
        identityToken: Data,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        guard let idToken = String(
            data: identityToken,
            encoding: .utf8
        ), let rawNonce else {
            self.rawNonce = nil
            throw AuthError.invalidCredential
        }

        self.rawNonce = nil
        return try await authClient.signInWithApple(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
    }
}

struct AppleAuthenticationButton: View {
    let coordinator: AppleSignInCoordinator
    let onCompletion: @MainActor (
        Result<AuthenticatedUser, AuthError>
    ) -> Void

    var body: some View {
        SignInWithAppleButton(
            .continue,
            onRequest: coordinator.prepare,
            onCompletion: { authorizationResult in
                Task { @MainActor in
                    do {
                        let user = try await coordinator.complete(
                            authorizationResult
                        )
                        onCompletion(.success(user))
                    } catch {
                        onCompletion(.failure(AuthError.map(error)))
                    }
                }
            }
        )
        .signInWithAppleButtonStyle(.whiteOutline)
        .frame(maxWidth: .infinity, minHeight: Layout.minimumControlHeight)
    }
}

import Foundation

struct AuthenticatedUser: Sendable, Equatable {
    let id: String
    let email: String?
    let displayName: String?
}

protocol AuthClient: Sendable {
    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser

    func restoreSession() async -> AuthenticatedUser?
    func signOut() async throws
}

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

    /// Signs a returning learner back in. Distinct from `restoreSession`, which
    /// only revives credentials Firebase already holds on this device.
    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser

    /// Sends a reset link. Succeeds even when no account matches the address so
    /// the caller cannot use it to discover which emails are registered.
    func sendPasswordReset(email: String) async throws

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

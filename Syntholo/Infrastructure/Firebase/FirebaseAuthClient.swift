import Foundation
@preconcurrency import FirebaseAuth

struct FirebaseAuthClient: AuthClient {
    typealias EmailAccountCreator = @Sendable (
        _ email: String,
        _ password: String
    ) async throws -> AuthenticatedUser
    typealias AppleSigner = @Sendable (
        _ idToken: String,
        _ rawNonce: String,
        _ fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser
    typealias GoogleSigner = @Sendable (
        _ idToken: String,
        _ accessToken: String
    ) async throws -> AuthenticatedUser

    private let createEmailUser: EmailAccountCreator
    private let signInAppleUser: AppleSigner
    private let signInGoogleUser: GoogleSigner
    private let restoreUser: @Sendable () async -> AuthenticatedUser?
    private let signOutUser: @Sendable () async throws -> Void

    init(auth: FirebaseAuth.Auth = .auth()) {
        let backend = FirebaseAuthBackend(auth: auth)
        createEmailUser = backend.createEmailAccount
        signInAppleUser = backend.signInWithApple
        signInGoogleUser = backend.signInWithGoogle
        restoreUser = backend.restoreSession
        signOutUser = backend.signOut
    }

    init(createEmailUser: @escaping EmailAccountCreator) {
        self.createEmailUser = createEmailUser
        signInAppleUser = Self.unavailableAppleSignIn
        signInGoogleUser = Self.unavailableGoogleSignIn
        restoreUser = { nil }
        signOutUser = {}
    }

    init(signInWithApple: @escaping AppleSigner) {
        createEmailUser = Self.unavailableEmailCreation
        signInAppleUser = signInWithApple
        signInGoogleUser = Self.unavailableGoogleSignIn
        restoreUser = { nil }
        signOutUser = {}
    }

    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.passwordTooShort
        }

        do {
            return try await createEmailUser(email, password)
        } catch {
            throw AuthError.map(error)
        }
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        do {
            return try await signInAppleUser(idToken, rawNonce, fullName)
        } catch {
            throw AuthError.map(error)
        }
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        do {
            return try await signInGoogleUser(idToken, accessToken)
        } catch {
            throw AuthError.map(error)
        }
    }

    func restoreSession() async -> AuthenticatedUser? {
        await restoreUser()
    }

    func signOut() async throws {
        do {
            try await signOutUser()
        } catch {
            throw AuthError.map(error)
        }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        return email.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    private static func unavailableEmailCreation(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    private static func unavailableAppleSignIn(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    private static func unavailableGoogleSignIn(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }
}

private final class FirebaseAuthBackend: @unchecked Sendable {
    private let auth: FirebaseAuth.Auth

    init(auth: FirebaseAuth.Auth) {
        self.auth = auth
    }

    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        let result = try await auth.createUser(
            withEmail: email,
            password: password
        )
        return Self.user(from: result.user)
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        let result = try await auth.signIn(with: credential)
        return Self.user(from: result.user)
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
        let result = try await auth.signIn(with: credential)
        return Self.user(from: result.user)
    }

    func restoreSession() async -> AuthenticatedUser? {
        auth.currentUser.map(Self.user)
    }

    func signOut() async throws {
        try auth.signOut()
    }

    private static func user(from user: FirebaseAuth.User) -> AuthenticatedUser {
        AuthenticatedUser(
            id: user.uid,
            email: user.email,
            displayName: user.displayName
        )
    }
}

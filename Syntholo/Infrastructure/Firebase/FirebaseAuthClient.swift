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

    typealias EmailSigner = @Sendable (
        _ email: String,
        _ password: String
    ) async throws -> AuthenticatedUser
    typealias PasswordResetSender = @Sendable (_ email: String) async throws -> Void

    private let createEmailUser: EmailAccountCreator
    private let signInEmailUser: EmailSigner
    private let sendReset: PasswordResetSender
    private let signInAppleUser: AppleSigner
    private let signInGoogleUser: GoogleSigner
    private let restoreUser: @Sendable () async -> AuthenticatedUser?
    private let signOutUser: @Sendable () async throws -> Void

    init(auth: FirebaseAuth.Auth = .auth()) {
        let backend = FirebaseAuthBackend(auth: auth)
        createEmailUser = backend.createEmailAccount
        signInEmailUser = backend.signInWithEmail
        sendReset = backend.sendPasswordReset
        signInAppleUser = backend.signInWithApple
        signInGoogleUser = backend.signInWithGoogle
        restoreUser = backend.restoreSession
        signOutUser = backend.signOut
    }

    init(createEmailUser: @escaping EmailAccountCreator) {
        self.createEmailUser = createEmailUser
        signInEmailUser = Self.unavailableEmailSignIn
        sendReset = Self.unavailablePasswordReset
        signInAppleUser = Self.unavailableAppleSignIn
        signInGoogleUser = Self.unavailableGoogleSignIn
        restoreUser = { nil }
        signOutUser = {}
    }

    init(signInWithEmail: @escaping EmailSigner) {
        createEmailUser = Self.unavailableEmailCreation
        signInEmailUser = signInWithEmail
        sendReset = Self.unavailablePasswordReset
        signInAppleUser = Self.unavailableAppleSignIn
        signInGoogleUser = Self.unavailableGoogleSignIn
        restoreUser = { nil }
        signOutUser = {}
    }

    init(sendPasswordReset: @escaping PasswordResetSender) {
        createEmailUser = Self.unavailableEmailCreation
        signInEmailUser = Self.unavailableEmailSignIn
        sendReset = sendPasswordReset
        signInAppleUser = Self.unavailableAppleSignIn
        signInGoogleUser = Self.unavailableGoogleSignIn
        restoreUser = { nil }
        signOutUser = {}
    }

    init(signInWithApple: @escaping AppleSigner) {
        createEmailUser = Self.unavailableEmailCreation
        signInEmailUser = Self.unavailableEmailSignIn
        sendReset = Self.unavailablePasswordReset
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

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(email) else {
            throw AuthError.invalidEmail
        }
        // No local length check here: an existing account may predate the
        // 8-character rule, and rejecting it locally would lock the owner out.
        guard !password.isEmpty else {
            throw AuthError.invalidCredential
        }

        do {
            return try await signInEmailUser(email, password)
        } catch {
            throw AuthError.map(error)
        }
    }

    func sendPasswordReset(email: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidEmail(email) else {
            throw AuthError.invalidEmail
        }

        do {
            try await sendReset(email)
        } catch {
            let mapped = AuthError.map(error)
            // Firebase reports an unknown address as "user not found". Swallow
            // it so the UI cannot be used to enumerate registered emails.
            guard mapped != .invalidCredential else {
                return
            }
            throw mapped
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

    private static func unavailableEmailSignIn(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    private static func unavailablePasswordReset(email: String) async throws {
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

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        let result = try await auth.signIn(withEmail: email, password: password)
        return Self.user(from: result.user)
    }

    func sendPasswordReset(email: String) async throws {
        try await auth.sendPasswordReset(withEmail: email)
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

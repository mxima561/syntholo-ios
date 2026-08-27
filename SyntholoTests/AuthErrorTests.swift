import AuthenticationServices
import Foundation
import XCTest
@testable import Syntholo

final class AuthErrorTests: XCTestCase {
    func testPasswordShorterThanEightCharactersIsRejectedBeforeFirebase() async {
        let recorder = EmailCreationRecorder()
        let client = FirebaseAuthClient(
            createEmailUser: { email, password in
                await recorder.record(email: email, password: password)
                return AuthenticatedUser(id: "unexpected", email: email, displayName: nil)
            }
        )

        do {
            _ = try await client.createEmailAccount(
                email: "learner@example.com",
                password: "1234567"
            )
            XCTFail("A seven-character password must be rejected")
        } catch {
            XCTAssertEqual(error as? AuthError, .passwordTooShort)
        }

        let requestCount = await recorder.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testInvalidEmailIsRejectedBeforeFirebase() async {
        let recorder = EmailCreationRecorder()
        let client = FirebaseAuthClient(
            createEmailUser: { email, password in
                await recorder.record(email: email, password: password)
                return AuthenticatedUser(id: "unexpected", email: email, displayName: nil)
            }
        )

        do {
            _ = try await client.createEmailAccount(
                email: "learner.example.com",
                password: "12345678"
            )
            XCTFail("A malformed email must be rejected")
        } catch {
            XCTAssertEqual(error as? AuthError, .invalidEmail)
        }

        let requestCount = await recorder.requestCount
        XCTAssertEqual(requestCount, 0)
    }

    func testValidEmailIsNormalizedBeforeFirebase() async throws {
        let recorder = EmailCreationRecorder()
        let client = FirebaseAuthClient(
            createEmailUser: { email, password in
                await recorder.record(email: email, password: password)
                return AuthenticatedUser(id: "user-1", email: email, displayName: nil)
            }
        )

        let user = try await client.createEmailAccount(
            email: "  Learner@Example.com  ",
            password: "12345678"
        )

        XCTAssertEqual(user.email, "Learner@Example.com")
        let lastEmail = await recorder.lastEmail
        let requestCount = await recorder.requestCount
        XCTAssertEqual(lastEmail, "Learner@Example.com")
        XCTAssertEqual(requestCount, 1)
    }

    func testAppleFullNameIsForwardedToFirebase() async throws {
        let recorder = AppleSignInRecorder()
        let client = FirebaseAuthClient(
            signInWithApple: { idToken, rawNonce, fullName in
                await recorder.record(
                    idToken: idToken,
                    rawNonce: rawNonce,
                    fullName: fullName
                )
                return AuthenticatedUser(
                    id: "apple-user",
                    email: nil,
                    displayName: fullName?.givenName
                )
            }
        )
        var name = PersonNameComponents()
        name.givenName = "Ada"
        name.familyName = "Lovelace"

        _ = try await client.signInWithApple(
            idToken: "id-token",
            rawNonce: "raw-nonce",
            fullName: name
        )

        let recordedName = await recorder.fullName
        XCTAssertEqual(recordedName?.givenName, "Ada")
        XCTAssertEqual(recordedName?.familyName, "Lovelace")
    }

    func testAppleCancellationMapsToCancelledWithoutABanner() {
        let error = NSError(
            domain: ASAuthorizationError.errorDomain,
            code: ASAuthorizationError.canceled.rawValue
        )

        let mapped = AuthError.map(error)

        XCTAssertEqual(mapped, .cancelled)
        XCTAssertFalse(mapped.shouldPresentMessage)
    }

    func testGoogleCancellationMapsToCancelledWithoutABanner() {
        let error = NSError(domain: "com.google.GIDSignIn", code: -5)

        let mapped = AuthError.map(error)

        XCTAssertEqual(mapped, .cancelled)
        XCTAssertFalse(mapped.shouldPresentMessage)
    }

    func testFirebaseErrorsMapToTypedAuthErrors() {
        let cases: [(Int, AuthError)] = [
            (17007, .emailAlreadyInUse),
            (17008, .invalidEmail),
            (17020, .networkUnavailable),
            (17026, .passwordTooShort)
        ]

        for (code, expected) in cases {
            XCTAssertEqual(
                AuthError.map(NSError(domain: "FIRAuthErrorDomain", code: code)),
                expected
            )
        }
    }

    func testMissingGoogleClientIDKeepsProviderUnconfigured() {
        let configuration = GoogleSignInConfiguration(
            clientID: nil,
            reversedClientScheme: nil
        )

        XCTAssertFalse(configuration.isConfigured)
    }

    func testCheckedInGooglePlaceholdersAreNotProductionConfiguration() {
        let configuration = GoogleSignInConfiguration(
            clientID: "syntholo-google-signin-not-configured",
            reversedClientScheme: "syntholo-google-signin-not-configured"
        )

        XCTAssertFalse(configuration.isConfigured)
    }
}

private actor EmailCreationRecorder {
    private(set) var requestCount = 0
    private(set) var lastEmail: String?

    func record(email: String, password: String) {
        requestCount += 1
        lastEmail = email
    }
}

private actor AppleSignInRecorder {
    private(set) var fullName: PersonNameComponents?

    func record(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) {
        self.fullName = fullName
    }
}

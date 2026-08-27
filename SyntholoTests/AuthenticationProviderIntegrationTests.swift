import AuthenticationServices
import Foundation
import XCTest
@testable import Syntholo

@MainActor
final class AuthenticationProviderIntegrationTests: XCTestCase {
    func testAppleRequestNonceAndFullNameReachInjectedAuthClient() async throws {
        let recorder = AppleCoordinatorRecorder()
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
        let coordinator = AppleSignInCoordinator(authClient: client)
        let request = ASAuthorizationAppleIDProvider().createRequest()
        var fullName = PersonNameComponents()
        fullName.givenName = "Ada"
        fullName.familyName = "Lovelace"

        coordinator.prepare(request)
        let user = try await coordinator.complete(
            identityToken: Data("apple-id-token".utf8),
            fullName: fullName
        )

        let forwarded = await recorder.values
        XCTAssertEqual(user.id, "apple-user")
        XCTAssertEqual(forwarded?.idToken, "apple-id-token")
        XCTAssertEqual(
            forwarded.map { AppleNonce.sha256($0.rawNonce) },
            request.nonce
        )
        XCTAssertEqual(forwarded?.fullName?.givenName, "Ada")
        XCTAssertEqual(forwarded?.fullName?.familyName, "Lovelace")
        XCTAssertEqual(request.requestedScopes, [.fullName, .email])
    }
}

private actor AppleCoordinatorRecorder {
    struct Values: Sendable {
        let idToken: String
        let rawNonce: String
        let fullName: PersonNameComponents?
    }

    private(set) var values: Values?

    func record(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) {
        values = Values(
            idToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
    }
}

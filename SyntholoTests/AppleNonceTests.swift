import XCTest
@testable import Syntholo

final class AppleNonceTests: XCTestCase {
    func testRandomNonceUsesRequestedLengthAndDocumentedCharacters() throws {
        let allowedCharacters = Set(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )

        for _ in 0..<20 {
            let nonce = try AppleNonce.random(length: 32)

            XCTAssertEqual(nonce.count, 32)
            XCTAssertTrue(nonce.allSatisfy(allowedCharacters.contains))
        }
    }

    func testSHA256MatchesKnownLowercaseHexadecimalDigest() {
        let digest = AppleNonce.sha256("abc")

        XCTAssertEqual(
            digest,
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(digest.count, 64)
        XCTAssertTrue(
            digest.allSatisfy { "0123456789abcdef".contains($0) }
        )
    }
}

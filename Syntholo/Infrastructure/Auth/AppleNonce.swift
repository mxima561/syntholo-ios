import CryptoKit
import Foundation
import Security

enum AppleNonceError: Error, Equatable {
    case invalidLength
    case randomGenerationFailed(OSStatus)
}

enum AppleNonce {
    private static let characters = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
    )

    static func random(length: Int = 32) throws -> String {
        guard length > 0 else {
            throw AppleNonceError.invalidLength
        }

        var result = ""
        result.reserveCapacity(length)

        while result.count < length {
            var randomByte: UInt8 = 0
            let status = SecRandomCopyBytes(
                kSecRandomDefault,
                MemoryLayout<UInt8>.size,
                &randomByte
            )
            guard status == errSecSuccess else {
                throw AppleNonceError.randomGenerationFailed(status)
            }

            if Int(randomByte) < characters.count {
                result.append(characters[Int(randomByte)])
            }
        }

        return result
    }

    static func sha256(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

import XCTest
@testable import Syntholo

final class FirebaseRuntimeConfigurationTests: XCTestCase {
    func testMissingConfigurationKeepsFirebaseUnavailable() {
        let configuration = FirebaseRuntimeConfiguration(
            environment: .development,
            options: nil,
            useEmulators: false
        )

        XCTAssertFalse(configuration.isConfigured)
    }

    func testEmulatorConfigurationUsesNonSecretProjectIdentity() {
        let configuration = FirebaseRuntimeConfiguration.emulator

        XCTAssertEqual(configuration.projectID, "syntholo-local")
        XCTAssertTrue(configuration.useEmulators)
    }
}

import FirebaseCore
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
        XCTAssertEqual(configuration.projectNumber, "emulator")
        XCTAssertTrue(configuration.useEmulators)
    }

    func testDevelopmentResolutionUsesEmulatorWithoutAPlist() {
        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .development,
            arguments: [],
            isRunningTests: false,
            optionsPath: { _ in
                XCTFail("Development must not load a credential plist")
                return nil
            }
        )

        XCTAssertEqual(configuration, .emulator)
    }

    func testUnitTestResolutionUsesEmulatorOutsideDevelopment() {
        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .staging,
            arguments: [],
            isRunningTests: true,
            optionsPath: { _ in
                XCTFail("Tests must not load a credential plist")
                return nil
            }
        )

        XCTAssertEqual(configuration, .emulator)
    }

    func testUITestingResolutionUsesEmulatorOutsideDevelopment() {
        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .production,
            arguments: ["--ui-testing"],
            isRunningTests: false,
            optionsPath: { _ in
                XCTFail("UI tests must not load a credential plist")
                return nil
            }
        )

        XCTAssertEqual(configuration, .emulator)
    }

    func testMissingStagingPlistKeepsFirebaseUnavailable() {
        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .staging,
            arguments: [],
            isRunningTests: false,
            optionsPath: { _ in nil }
        )

        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertFalse(configuration.isConfigured)
        XCTAssertFalse(configuration.useEmulators)
    }

    func testMalformedProductionPlistKeepsFirebaseUnavailable() throws {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("plist")
        let malformedPlist: [String: Any] = [
            "PLIST_VERSION": "1",
            "PROJECT_ID": "syntactically-valid-but-incomplete"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: malformedPlist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
        defer { try? FileManager.default.removeItem(at: plistURL) }

        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .production,
            arguments: [],
            isRunningTests: false,
            optionsPath: { _ in plistURL.path }
        )

        XCTAssertEqual(configuration.environment, .production)
        XCTAssertFalse(configuration.isConfigured)
        XCTAssertNil(configuration.projectID)
        XCTAssertNil(configuration.projectNumber)
    }

    func testValidStagingPlistProducesConfiguredCloudRuntime() throws {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("plist")
        let plist: [String: Any] = [
            "API_KEY": "A" + String(repeating: "0", count: 38),
            "BUNDLE_ID": "com.syntholo.ios",
            "GCM_SENDER_ID": "1234567890",
            "GOOGLE_APP_ID": "1:1234567890:ios:abcdef1234567890",
            "PLIST_VERSION": "1",
            "PROJECT_ID": "syntholo-staging-fixture"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
        defer { try? FileManager.default.removeItem(at: plistURL) }

        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .staging,
            arguments: [],
            isRunningTests: false,
            optionsPath: { _ in plistURL.path }
        )

        XCTAssertEqual(configuration.environment, .staging)
        XCTAssertEqual(configuration.projectID, "syntholo-staging-fixture")
        XCTAssertEqual(configuration.projectNumber, "1234567890")
        XCTAssertTrue(configuration.isConfigured)
        XCTAssertFalse(configuration.useEmulators)
    }

    func testCloudConfigurationRejectsMismatchedProjectNumbers() throws {
        let plistURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("plist")
        let plist: [String: Any] = [
            "API_KEY": "A" + String(repeating: "0", count: 38),
            "BUNDLE_ID": "com.syntholo.ios",
            "GCM_SENDER_ID": "1234567890",
            "GOOGLE_APP_ID": "1:9999999999:ios:abcdef1234567890",
            "PLIST_VERSION": "1",
            "PROJECT_ID": "syntholo-staging-fixture"
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL)
        defer { try? FileManager.default.removeItem(at: plistURL) }

        let configuration = FirebaseRuntimeConfiguration.resolve(
            environment: .staging,
            arguments: [],
            isRunningTests: false,
            optionsPath: { _ in plistURL.path }
        )

        XCTAssertFalse(configuration.isConfigured)
        XCTAssertNil(configuration.projectID)
        XCTAssertNil(configuration.projectNumber)
    }

    func testCurriculumSourceIdentityMustMatchTheFirestoreApp() throws {
        let emulatorIdentity = try CurriculumRepositorySourceIdentity(
            configuration: .emulator,
            firestoreProjectID: "syntholo-local",
            firestoreProjectNumber: "1234567890"
        )
        XCTAssertEqual(emulatorIdentity.environment, .development)
        XCTAssertEqual(emulatorIdentity.projectID, "syntholo-local")
        XCTAssertEqual(emulatorIdentity.projectNumber, "emulator")

        let options = FirebaseOptions(
            googleAppID: "1:1234567890:ios:abcdef1234567890",
            gcmSenderID: "1234567890"
        )
        options.apiKey = "A" + String(repeating: "0", count: 38)
        options.projectID = "syntholo-staging-fixture"
        let staging = FirebaseRuntimeConfiguration(
            environment: .staging,
            options: options,
            useEmulators: false
        )
        let stagingIdentity = try CurriculumRepositorySourceIdentity(
            configuration: staging,
            firestoreProjectID: "syntholo-staging-fixture",
            firestoreProjectNumber: "1234567890"
        )
        XCTAssertEqual(stagingIdentity.environment, .staging)
        XCTAssertEqual(stagingIdentity.projectNumber, "1234567890")

        XCTAssertThrowsError(
            try CurriculumRepositorySourceIdentity(
                configuration: staging,
                firestoreProjectID: "syntholo-production-fixture",
                firestoreProjectNumber: "1234567890"
            )
        ) { error in
            XCTAssertEqual(error as? CurriculumRepositoryError, .wrongEnvironment)
        }
        XCTAssertThrowsError(
            try CurriculumRepositorySourceIdentity(
                configuration: staging,
                firestoreProjectID: "syntholo-staging-fixture",
                firestoreProjectNumber: "9999999999"
            )
        ) { error in
            XCTAssertEqual(error as? CurriculumRepositoryError, .wrongEnvironment)
        }
    }

    @MainActor
    func testUnavailableConfigurationMakesBootstrapReturnFalse() {
        let configuration = FirebaseRuntimeConfiguration(
            environment: .production,
            options: nil,
            useEmulators: false
        )

        XCTAssertFalse(FirebaseBootstrap.configure(configuration))
    }

    func testUnavailableFirebaseSelectsSetupSafePresentation() {
        let presentation = SyntholoRootPresentation(
            isFirebaseConfigured: false
        )

        XCTAssertEqual(presentation, .configurationRequired)
    }

    func testSetupSafeStringsResolveFromLocalizationCatalog() {
        let locale = Locale(identifier: "en")

        XCTAssertEqual(
            String(
                localized: "firebase_setup_required_title",
                bundle: .main,
                locale: locale
            ),
            "Setup required"
        )
        XCTAssertEqual(
            String(
                localized: "firebase_setup_required_message",
                bundle: .main,
                locale: locale
            ),
            "Firebase configuration is missing. See docs/setup/firebase.md."
        )
    }
}

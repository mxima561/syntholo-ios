import XCTest
@testable import Syntholo

@MainActor
final class SyntholoLaunchCompositionTests: XCTestCase {
    func testEveryCurriculumFixtureSelectsUITestingBeforeFirebaseComposition() {
        for fixture in DebugCurriculumFixture.allCases {
            var configurationReads = 0
            var firebaseBootstrapCalls = 0
            var uiTestingCalls = 0
            var liveDependencyCalls = 0

            let composition = SyntholoLaunchComposition.make(
                arguments: [
                    "--ui-testing",
                    fixture.launchArgument,
                    "--onboarding-reset",
                    "--provider-fixture=success",
                ],
                readFirebaseConfiguration: {
                    configurationReads += 1
                    return .emulator
                },
                configureFirebase: { _, _ in
                    firebaseBootstrapCalls += 1
                    return true
                },
                makeUITestingDependencies: { arguments in
                    uiTestingCalls += 1
                    return AppDependencies.makeUITesting(
                        arguments: arguments
                    )
                },
                makeLiveDependencies: { _, _ in
                    liveDependencyCalls += 1
                    return AppDependencies.makeUITesting(
                        arguments: ["--ui-testing"]
                    )
                }
            )

            XCTAssertEqual(
                composition.rootPresentation,
                .application,
                fixture.rawValue
            )
            XCTAssertEqual(uiTestingCalls, 1, fixture.rawValue)
            XCTAssertEqual(configurationReads, 0, fixture.rawValue)
            XCTAssertEqual(firebaseBootstrapCalls, 0, fixture.rawValue)
            XCTAssertEqual(liveDependencyCalls, 0, fixture.rawValue)
        }
    }

    func testMissingOrNonExactUITestingTokenSelectsFirebaseComposition() {
        for arguments in [
            [String](),
            ["--ui-testing=true"],
            ["--ui-testing ", "--curriculum-fixture=fresh"],
            ["--curriculum-fixture=fresh"],
        ] {
            var configurationReads = 0
            var firebaseBootstrapCalls = 0
            var uiTestingCalls = 0
            var liveDependencyCalls = 0

            let composition = SyntholoLaunchComposition.make(
                arguments: arguments,
                readFirebaseConfiguration: {
                    configurationReads += 1
                    return .emulator
                },
                configureFirebase: { configuration, receivedArguments in
                    firebaseBootstrapCalls += 1
                    XCTAssertEqual(configuration, .emulator)
                    XCTAssertEqual(receivedArguments, arguments)
                    return true
                },
                makeUITestingDependencies: { _ in
                    uiTestingCalls += 1
                    return AppDependencies.makeUITesting(
                        arguments: ["--ui-testing"]
                    )
                },
                makeLiveDependencies: {
                    configuration,
                    isFirebaseConfigured in
                    liveDependencyCalls += 1
                    XCTAssertEqual(configuration, .emulator)
                    XCTAssertTrue(isFirebaseConfigured)
                    return AppDependencies.makeUITesting(
                        arguments: ["--ui-testing"]
                    )
                }
            )

            XCTAssertEqual(
                composition.rootPresentation,
                .application,
                "\(arguments)"
            )
            XCTAssertEqual(uiTestingCalls, 0, "\(arguments)")
            XCTAssertEqual(configurationReads, 1, "\(arguments)")
            XCTAssertEqual(firebaseBootstrapCalls, 1, "\(arguments)")
            XCTAssertEqual(liveDependencyCalls, 1, "\(arguments)")
        }
    }

    func testFirebaseBootstrapFailsClosedBeforeSDKConfigurationForUITesting() {
        XCTAssertFalse(
            FirebaseBootstrap.configure(
                .emulator,
                arguments: ["--ui-testing"]
            )
        )
    }
}

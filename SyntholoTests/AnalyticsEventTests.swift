import XCTest
@testable import Syntholo

@MainActor
final class AnalyticsEventTests: XCTestCase {
    func testPhaseOneEventNamesAndTypedPayloadsAreExact() {
        let fixtures: [(AnalyticsEvent, AnalyticsPayload)] = [
            (
                .onboardingStarted,
                .init(name: .onboardingStarted, parameters: [])
            ),
            (
                .onboardingCompleted,
                .init(name: .onboardingCompleted, parameters: [])
            ),
            (
                .ageConfirmed,
                .init(name: .ageConfirmed, parameters: [])
            ),
            (
                .goalSelected(.studySmarter),
                .init(
                    name: .goalSelected,
                    parameters: [.goal(.studySmarter)]
                )
            ),
            (
                .pathRecommended(.school),
                .init(
                    name: .pathRecommended,
                    parameters: [.path(.school)]
                )
            ),
            (
                .pathSelected(.creation),
                .init(
                    name: .pathSelected,
                    parameters: [.path(.creation)]
                )
            ),
            (
                .coachModeSelected(.socratic),
                .init(
                    name: .coachModeSelected,
                    parameters: [.coachMode(.socratic)]
                )
            ),
            (
                .accountCreated(.apple),
                .init(
                    name: .accountCreated,
                    parameters: [.authenticationProvider(.apple)]
                )
            ),
            (
                .loginCompleted(restoredSession: true),
                .init(
                    name: .loginCompleted,
                    parameters: [.restoredSession(true)]
                )
            ),
        ]

        for (event, expected) in fixtures {
            XCTAssertEqual(event.payload, expected, "Wrong payload for \(event)")
        }

        XCTAssertEqual(
            Set(fixtures.map { $0.1.name.rawValue }),
            [
                "onboarding_started",
                "onboarding_completed",
                "age_confirmed",
                "goal_selected",
                "path_recommended",
                "path_selected",
                "coach_mode_selected",
                "account_created",
                "login_completed",
            ]
        )
    }

    func testEncodedAnalyticsNeverContainsForbiddenPrivateKeys() {
        let events: [AnalyticsEvent] = [
            .onboardingStarted,
            .onboardingCompleted,
            .ageConfirmed,
            .goalSelected(.buildWithAI),
            .pathRecommended(.build),
            .pathSelected(.build),
            .coachModeSelected(.strict),
            .accountCreated(.google),
            .loginCompleted(restoredSession: true),
        ]
        let forbiddenKeys = Set([
            "email",
            "displayName",
            "birthDate",
            "prompt",
            "answer",
        ])

        let encodedKeys = Set(
            events
                .flatMap(\.payload.parameters)
                .map(\.key.rawValue)
        )

        XCTAssertTrue(encodedKeys.isDisjoint(with: forbiddenKeys))
        XCTAssertFalse(encodedKeys.contains("age_band"))
    }

    func testFirebaseAdapterMapsOnlyEnumeratedValuesAndBooleans() {
        let recorder = FirebaseAnalyticsRecorder()
        let client = FirebaseAnalyticsClient(logEvent: recorder.log)

        client.log(.goalSelected(.workProductivity))
        client.log(.pathSelected(.work))
        client.log(.coachModeSelected(.chill))
        client.log(.accountCreated(.password))
        client.log(.loginCompleted(restoredSession: true))

        XCTAssertEqual(
            recorder.events,
            [
                .init(
                    name: "goal_selected",
                    parameters: ["goal": .string("workProductivity")]
                ),
                .init(
                    name: "path_selected",
                    parameters: ["path": .string("work")]
                ),
                .init(
                    name: "coach_mode_selected",
                    parameters: ["coach_mode": .string("chill")]
                ),
                .init(
                    name: "account_created",
                    parameters: ["auth_provider": .string("password")]
                ),
                .init(
                    name: "login_completed",
                    parameters: ["restored_session": .bool(true)]
                ),
            ]
        )
    }
}

@MainActor
private final class FirebaseAnalyticsRecorder {
    struct Event: Equatable {
        let name: String
        let parameters: [String: FirebaseAnalyticsValue]
    }

    private(set) var events: [Event] = []

    func log(
        name: String,
        parameters: [String: FirebaseAnalyticsValue]
    ) {
        events.append(Event(name: name, parameters: parameters))
    }
}

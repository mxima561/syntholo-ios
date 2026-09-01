import XCTest
@testable import Syntholo

final class DebugCurriculumFixturesTests: XCTestCase {
    func testSelectionDefaultsToFreshAndAcceptsEveryExactMode() throws {
        XCTAssertEqual(
            try DebugCurriculumFixtures.selection(arguments: ["--ui-testing"]),
            .fresh
        )

        for fixture in DebugCurriculumFixture.allCases {
            XCTAssertEqual(
                try DebugCurriculumFixtures.selection(
                    arguments: ["--ui-testing", fixture.launchArgument]
                ),
                fixture
            )
        }
    }

    func testSelectionRejectsUnknownAndDuplicateModes() {
        XCTAssertThrowsError(
            try DebugCurriculumFixtures.selection(
                arguments: [
                    "--ui-testing",
                    "--curriculum-fixture=not-a-contract-mode",
                ]
            )
        )
        XCTAssertThrowsError(
            try DebugCurriculumFixtures.selection(
                arguments: [
                    "--ui-testing",
                    DebugCurriculumFixture.fresh.launchArgument,
                    DebugCurriculumFixture.saved.launchArgument,
                ]
            )
        )
    }

    func testTerminalFixtureEventContractsAreExact() async throws {
        let snapshot = try DebugCurriculumFixtures.snapshot()
        let requiredSchema = CurriculumSchema.currentVersion + 1
        let expected: [(DebugCurriculumFixture, [CurriculumLoadEvent])] = [
            (.fresh, [.fresh(snapshot)]),
            (
                .saved,
                [
                    .saved(snapshot),
                    .unavailable(
                        error: .networkUnavailable,
                        saved: snapshot
                    ),
                ]
            ),
            (
                .savedToFresh,
                [.saved(snapshot), .fresh(snapshot)]
            ),
            (
                .offlineNoCache,
                [
                    .unavailable(
                        error: .networkUnavailable,
                        saved: nil
                    ),
                ]
            ),
            (
                .incompatibleWithFallback,
                [
                    .updateRequired(
                        requiredSchema: requiredSchema,
                        saved: snapshot
                    ),
                ]
            ),
            (
                .incompatibleWithoutFallback,
                [
                    .updateRequired(
                        requiredSchema: requiredSchema,
                        saved: nil
                    ),
                ]
            ),
            (.empty, [.empty]),
            (
                .malformed,
                [
                    .unavailable(
                        error: .malformedDocument(
                            path: "debug-fixture/catalog"
                        ),
                        saved: nil
                    ),
                ]
            ),
        ]

        for (fixture, expectedEvents) in expected {
            let repository = try DebugCurriculumFixtures.repository(
                fixture: fixture,
                transitionDelayNanoseconds: 0
            )
            var actualEvents: [CurriculumLoadEvent] = []
            for await event in repository.load(locale: snapshot.locale) {
                actualEvents.append(event)
            }
            XCTAssertEqual(actualEvents, expectedEvents, fixture.rawValue)
        }
    }

    func testFailOnceRepositoryRetainsAttemptAcrossSubscriptions() async throws {
        let snapshot = try DebugCurriculumFixtures.snapshot()
        let repository = try DebugCurriculumFixtures.repository(
            fixture: .failOnceRetry,
            transitionDelayNanoseconds: 0
        )

        var firstEvents: [CurriculumLoadEvent] = []
        for await event in repository.load(locale: snapshot.locale) {
            firstEvents.append(event)
        }
        var secondEvents: [CurriculumLoadEvent] = []
        for await event in repository.load(locale: snapshot.locale) {
            secondEvents.append(event)
        }

        XCTAssertEqual(
            firstEvents,
            [
                .unavailable(
                    error: .networkUnavailable,
                    saved: nil
                ),
            ]
        )
        XCTAssertEqual(secondEvents, [.fresh(snapshot)])
    }

    func testLoadingRepositoryEmitsNothingUntilCancellation() async throws {
        let snapshot = try DebugCurriculumFixtures.snapshot()
        let repository = try DebugCurriculumFixtures.repository(
            fixture: .loading,
            transitionDelayNanoseconds: 0
        )
        let startedExpectation = expectation(
            description: "Loading consumer started"
        )
        let eventExpectation = expectation(description: "No loading event")
        eventExpectation.isInverted = true
        let task = Task {
            startedExpectation.fulfill()
            for await _ in repository.load(locale: snapshot.locale) {
                eventExpectation.fulfill()
            }
        }

        await fulfillment(of: [startedExpectation], timeout: 1)
        await fulfillment(of: [eventExpectation], timeout: 0.1)
        task.cancel()
        await task.value
    }
}

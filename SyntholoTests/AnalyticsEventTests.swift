import SwiftUI
import UIKit
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

    func testEncodedAnalyticsNeverContainsForbiddenPrivateKeysOrValues() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let rubric = try XCTUnwrap(
            snapshot.rubricVersions.first {
                $0.rubricVersionID == lesson.rubricVersionID
            }
        )
        let catalogVersion = snapshot.catalogVersion.version
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
            .programViewed(
                ProgramViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    source: .fresh
                )
            ),
            .moduleViewed(
                ModuleViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    source: .saved
                )
            ),
            .lessonViewed(
                LessonViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    lessonID: lesson.lessonID,
                    lessonVersion: lesson.version,
                    rubricID: rubric.rubricID,
                    rubricVersion: rubric.version,
                    source: .fresh,
                    durationBucket: .minutes1To5
                )
            ),
        ]
        let forbiddenKeys = Set([
            "email",
            "display_name",
            "birth_date",
            "profile",
            "operator",
            "title",
            "body",
            "question",
            "options",
            "correct_answer",
            "correct_option_id",
            "feedback",
            "correct_feedback",
            "incorrect_feedback",
            "prompt",
            "answer",
            "submission",
        ])

        let encodedKeys = Set(
            events
                .flatMap(\.payload.parameters)
                .map(\.key.rawValue)
        )

        XCTAssertTrue(encodedKeys.isDisjoint(with: forbiddenKeys))
        XCTAssertFalse(encodedKeys.contains("age_band"))

        let recorder = FirebaseAnalyticsRecorder()
        let client = FirebaseAnalyticsClient(logEvent: recorder.log)
        for event in events {
            client.log(event)
        }
        let encodedStringValues = recorder.events.flatMap { event in
            event.parameters.values.compactMap { value -> String? in
                guard case let .string(string) = value else {
                    return nil
                }
                return string
            }
        }
        let forbiddenValues = [
            "SYNTHETIC-CONTRACT-FIXTURE-NEVER-PUBLISH",
            "Synthetic placeholder program used only to validate the curriculum contract.",
            "Synthetic contract module",
            "Synthetic placeholder module used only for graph validation.",
            "Synthetic contract lesson",
            "Validate a synthetic placeholder graph without supplying editorial curriculum.",
            "Synthetic placeholder text for contract validation only.",
            "Which synthetic option is the fixture's deterministic contract sentinel?",
            "Synthetic option A",
            "synthetic-option-a",
            "Synthetic correct-feedback placeholder.",
            "Synthetic incorrect-feedback placeholder.",
            "learner@example.com",
            "PRIVATE-PROFILE-SENTINEL",
            "OPERATOR-SENTINEL",
        ]

        for forbiddenValue in forbiddenValues {
            XCTAssertFalse(
                encodedStringValues.contains(where: {
                    $0.localizedCaseInsensitiveContains(forbiddenValue)
                }),
                "Analytics leaked forbidden value: \(forbiddenValue)"
            )
        }
    }

    func testCurriculumViewEventNamesAndTypedPayloadsAreExact() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let rubric = try XCTUnwrap(
            snapshot.rubricVersions.first {
                $0.rubricVersionID == lesson.rubricVersionID
            }
        )
        let catalogVersion = snapshot.catalogVersion.version
        let durationBucket = try XCTUnwrap(
            CurriculumDurationBucket(
                expectedMinutes: lesson.expectedDurationMinutes
            )
        )

        XCTAssertEqual(
            AnalyticsEvent.programViewed(
                ProgramViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    source: .fresh
                )
            ).payload,
            AnalyticsPayload(
                name: .programViewed,
                parameters: [
                    .locale(snapshot.locale),
                    .catalogVersion(catalogVersion),
                    .programID(program.programID),
                    .programVersion(program.version),
                    .curriculumSource(.fresh),
                ]
            )
        )
        XCTAssertEqual(
            AnalyticsEvent.moduleViewed(
                ModuleViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    source: .saved
                )
            ).payload,
            AnalyticsPayload(
                name: .moduleViewed,
                parameters: [
                    .locale(snapshot.locale),
                    .catalogVersion(catalogVersion),
                    .programID(program.programID),
                    .programVersion(program.version),
                    .moduleID(module.moduleID),
                    .moduleVersion(module.version),
                    .curriculumSource(.saved),
                ]
            )
        )
        XCTAssertEqual(
            AnalyticsEvent.lessonViewed(
                LessonViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    lessonID: lesson.lessonID,
                    lessonVersion: lesson.version,
                    rubricID: rubric.rubricID,
                    rubricVersion: rubric.version,
                    source: .fresh,
                    durationBucket: durationBucket
                )
            ).payload,
            AnalyticsPayload(
                name: .lessonViewed,
                parameters: [
                    .locale(snapshot.locale),
                    .catalogVersion(catalogVersion),
                    .programID(program.programID),
                    .programVersion(program.version),
                    .moduleID(module.moduleID),
                    .moduleVersion(module.version),
                    .lessonID(lesson.lessonID),
                    .lessonVersion(lesson.version),
                    .rubricID(rubric.rubricID),
                    .rubricVersion(rubric.version),
                    .curriculumSource(.fresh),
                    .durationBucket(durationBucket),
                ]
            )
        )
    }

    func testCurriculumDurationBucketsAreClosedAndBounded() {
        XCTAssertNil(CurriculumDurationBucket(expectedMinutes: 0))
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 1),
            .minutes1To5
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 5),
            .minutes1To5
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 6),
            .minutes6To10
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 10),
            .minutes6To10
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 11),
            .minutes11To20
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 20),
            .minutes11To20
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 21),
            .minutes21To40
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 40),
            .minutes21To40
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 41),
            .minutes41To180
        )
        XCTAssertEqual(
            CurriculumDurationBucket(expectedMinutes: 180),
            .minutes41To180
        )
        XCTAssertNil(CurriculumDurationBucket(expectedMinutes: 181))
    }

    func testAnalyticsParameterKeysAreAnExactPrivacyAllowlist() {
        XCTAssertEqual(
            Set(AnalyticsEventName.allCases.map(\.rawValue)),
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
                "program_viewed",
                "module_viewed",
                "lesson_viewed",
            ]
        )
        XCTAssertEqual(
            Set(AnalyticsParameterKey.allCases.map(\.rawValue)),
            [
                "goal",
                "path",
                "coach_mode",
                "auth_provider",
                "restored_session",
                "locale",
                "catalog_version",
                "program_id",
                "program_version",
                "module_id",
                "module_version",
                "lesson_id",
                "lesson_version",
                "rubric_id",
                "rubric_version",
                "content_source",
                "duration_bucket",
            ]
        )
    }

    func testLearnDestinationEmitsOnceAcrossBodyReevaluationAndAgainWhenRecreated() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = ControllableAnalyticsCurriculumRepository()
        let analytics = RecordingAnalyticsClient()
        let store = CurriculumStore(
            repository: repository,
            locale: snapshot.locale,
            analytics: analytics
        )
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let catalogVersionID = snapshot.catalogVersion.catalogVersionID
        let programReference = ProgramVersionReference(
            locale: snapshot.locale,
            catalogVersionID: catalogVersionID,
            programVersionID: program.programVersionID
        )
        let savedProgramContext = ProgramViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            source: .saved
        )
        let freshProgramContext = ProgramViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            source: .fresh
        )
        let route = LearnRoute.program(programReference)
        let router = AppRouter()

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(snapshot))
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
        }

        let host = UIHostingController(
            rootView: LearnHomeView(store: store, router: router)
        )
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        router.learnPath = [route]
        await assertEventually {
            host.view.layoutIfNeeded()
            return analytics.events.count == 1
        }

        XCTAssertEqual(
            analytics.events,
            [.programViewed(savedProgramContext)]
        )

        repository.yield(.fresh(snapshot))
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }
        await drainViewUpdates(host)
        XCTAssertEqual(analytics.events.count, 1)

        router.learnPath = []
        await drainViewUpdates(host)
        router.learnPath = [route]
        await assertEventually {
            host.view.layoutIfNeeded()
            return analytics.events.count == 2
        }

        XCTAssertEqual(
            analytics.events,
            [
                .programViewed(savedProgramContext),
                .programViewed(freshProgramContext),
            ]
        )
    }

    func testCurriculumStoreLogsValidatedRoutesAndRejectsUnresolvedRoutes() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = ControllableAnalyticsCurriculumRepository()
        let analytics = RecordingAnalyticsClient()
        let store = CurriculumStore(
            repository: repository,
            locale: snapshot.locale,
            analytics: analytics
        )
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let rubric = try XCTUnwrap(
            snapshot.rubricVersions.first {
                $0.rubricVersionID == lesson.rubricVersionID
            }
        )
        let programReference = ProgramVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID
        )
        let moduleReference = ModuleVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID
        )
        let lessonReference = LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: lesson.rubricVersionID
        )
        let missingProgramID = CurriculumVersionID(
            stableID: try CurriculumStableID("missing-program"),
            locale: snapshot.locale,
            version: try CurriculumVersion(1)
        )
        let unresolvedRoute = LearnRoute.program(
            ProgramVersionReference(
                locale: snapshot.locale,
                catalogVersionID: snapshot.catalogVersion.catalogVersionID,
                programVersionID: missingProgramID
            )
        )
        let programContext = ProgramViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            source: .fresh
        )
        let moduleContext = ModuleViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            moduleID: module.moduleID,
            moduleVersion: module.version,
            source: .fresh
        )
        let lessonContext = LessonViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            moduleID: module.moduleID,
            moduleVersion: module.version,
            lessonID: lesson.lessonID,
            lessonVersion: lesson.version,
            rubricID: rubric.rubricID,
            rubricVersion: rubric.version,
            source: .fresh,
            durationBucket: .minutes1To5
        )

        XCTAssertFalse(store.recordPresentation(of: unresolvedRoute))
        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.fresh(snapshot))
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }

        XCTAssertTrue(
            store.recordPresentation(of: .program(programReference))
        )
        XCTAssertTrue(
            store.recordPresentation(of: .module(moduleReference))
        )
        XCTAssertTrue(
            store.recordPresentation(of: .lesson(lessonReference))
        )
        XCTAssertFalse(store.recordPresentation(of: unresolvedRoute))
        XCTAssertEqual(
            analytics.events,
            [
                .programViewed(programContext),
                .moduleViewed(moduleContext),
                .lessonViewed(lessonContext),
            ]
        )
    }

    func testDirectLessonPreviewLogsOnlyLessonViewed() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = ControllableAnalyticsCurriculumRepository()
        let analytics = RecordingAnalyticsClient()
        let store = CurriculumStore(
            repository: repository,
            locale: snapshot.locale,
            analytics: analytics
        )
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let rubric = try XCTUnwrap(
            snapshot.rubricVersions.first {
                $0.rubricVersionID == lesson.rubricVersionID
            }
        )
        let reference = LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: lesson.rubricVersionID
        )
        let lessonContext = LessonViewAnalyticsContext(
            locale: snapshot.locale,
            catalogVersion: snapshot.catalogVersion.version,
            programID: program.programID,
            programVersion: program.version,
            moduleID: module.moduleID,
            moduleVersion: module.version,
            lessonID: lesson.lessonID,
            lessonVersion: lesson.version,
            rubricID: rubric.rubricID,
            rubricVersion: rubric.version,
            source: .fresh,
            durationBucket: .minutes1To5
        )
        let router = AppRouter()

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.fresh(snapshot))
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }

        let host = UIHostingController(
            rootView: LearnHomeView(store: store, router: router)
        )
        let window = UIWindow(
            frame: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        router.learnPath = [.lesson(reference)]
        await assertEventually {
            host.view.layoutIfNeeded()
            return analytics.events.count == 1
        }

        XCTAssertEqual(
            analytics.events,
            [.lessonViewed(lessonContext)]
        )
    }

    func testFirebaseAdapterMapsOnlyDocumentedEnumeratedAndIntegerValues() {
        let recorder = FirebaseAnalyticsRecorder()
        let client = FirebaseAnalyticsClient(logEvent: recorder.log)

        client.log(.goalSelected(.workProductivity))
        client.log(.pathSelected(.work))
        client.log(.coachModeSelected(.chill))
        client.log(.accountCreated(.password))
        client.log(.loginCompleted(restoredSession: true))
        client.log(.loginCompleted(restoredSession: false))

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
                    parameters: ["restored_session": .integer(1)]
                ),
                .init(
                    name: "login_completed",
                    parameters: ["restored_session": .integer(0)]
                ),
            ]
        )
    }

    func testFirebaseAdapterMapsCurriculumEventsWithoutFreeFormValues() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let rubric = try XCTUnwrap(
            snapshot.rubricVersions.first {
                $0.rubricVersionID == lesson.rubricVersionID
            }
        )
        let catalogVersion = snapshot.catalogVersion.version
        let recorder = FirebaseAnalyticsRecorder()
        let client = FirebaseAnalyticsClient(logEvent: recorder.log)

        let events: [AnalyticsEvent] = [
            .programViewed(
                ProgramViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    source: .fresh
                )
            ),
            .moduleViewed(
                ModuleViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    source: .saved
                )
            ),
            .lessonViewed(
                LessonViewAnalyticsContext(
                    locale: snapshot.locale,
                    catalogVersion: catalogVersion,
                    programID: program.programID,
                    programVersion: program.version,
                    moduleID: module.moduleID,
                    moduleVersion: module.version,
                    lessonID: lesson.lessonID,
                    lessonVersion: lesson.version,
                    rubricID: rubric.rubricID,
                    rubricVersion: rubric.version,
                    source: .fresh,
                    durationBucket: .minutes11To20
                )
            ),
        ]
        for event in events {
            let keys = event.payload.parameters.map(\.key)
            XCTAssertEqual(keys.count, Set(keys).count)
            client.log(event)
        }

        XCTAssertEqual(
            recorder.events,
            [
                .init(
                    name: "program_viewed",
                    parameters: [
                        "locale": .string(snapshot.locale.rawValue),
                        "catalog_version": .integer(
                            catalogVersion.rawValue
                        ),
                        "program_id": .string(program.programID.rawValue),
                        "program_version": .integer(program.version.rawValue),
                        "content_source": .string("fresh"),
                    ]
                ),
                .init(
                    name: "module_viewed",
                    parameters: [
                        "locale": .string(snapshot.locale.rawValue),
                        "catalog_version": .integer(
                            catalogVersion.rawValue
                        ),
                        "program_id": .string(program.programID.rawValue),
                        "program_version": .integer(program.version.rawValue),
                        "module_id": .string(module.moduleID.rawValue),
                        "module_version": .integer(module.version.rawValue),
                        "content_source": .string("saved"),
                    ]
                ),
                .init(
                    name: "lesson_viewed",
                    parameters: [
                        "locale": .string(snapshot.locale.rawValue),
                        "catalog_version": .integer(
                            catalogVersion.rawValue
                        ),
                        "program_id": .string(program.programID.rawValue),
                        "program_version": .integer(program.version.rawValue),
                        "module_id": .string(module.moduleID.rawValue),
                        "module_version": .integer(module.version.rawValue),
                        "lesson_id": .string(lesson.lessonID.rawValue),
                        "lesson_version": .integer(lesson.version.rawValue),
                        "rubric_id": .string(rubric.rubricID.rawValue),
                        "rubric_version": .integer(rubric.version.rawValue),
                        "content_source": .string("fresh"),
                        "duration_bucket": .string("11_20_minutes"),
                    ]
                ),
            ]
        )
    }

    func testFirebaseCurriculumParametersStayWithinStandardCollectionLimits() throws {
        let locale = try CurriculumLocale(
            "x-aaaaaaaa-bbbbbbbb-cccccccc-dddddd"
        )
        let stableID = try CurriculumStableID(
            String(repeating: "a", count: 64)
        )
        let version = try CurriculumVersion(CurriculumVersion.maximum)
        let longVersionID = CurriculumVersionID(
            stableID: stableID,
            locale: locale,
            version: version
        )
        let context = LessonViewAnalyticsContext(
            locale: locale,
            catalogVersion: version,
            programID: stableID,
            programVersion: version,
            moduleID: stableID,
            moduleVersion: version,
            lessonID: stableID,
            lessonVersion: version,
            rubricID: stableID,
            rubricVersion: version,
            source: .fresh,
            durationBucket: .minutes41To180
        )
        XCTAssertEqual(locale.rawValue.utf8.count, 35)
        XCTAssertEqual(stableID.rawValue.utf8.count, 64)
        XCTAssertEqual(longVersionID.rawValue.utf8.count, 114)

        let recorder = FirebaseAnalyticsRecorder()
        let client = FirebaseAnalyticsClient(logEvent: recorder.log)
        client.log(.lessonViewed(context))

        let event = try XCTUnwrap(recorder.events.first)
        XCTAssertEqual(recorder.events.count, 1)
        XCTAssertLessThanOrEqual(event.name.utf8.count, 40)
        XCTAssertLessThanOrEqual(event.parameters.count, 25)
        for (name, value) in event.parameters {
            XCTAssertLessThanOrEqual(name.utf8.count, 40)
            if case let .string(string) = value {
                XCTAssertLessThanOrEqual(string.utf8.count, 100)
            }
        }
        XCTAssertEqual(
            event.parameters["lesson_id"],
            .string(stableID.rawValue)
        )
        XCTAssertEqual(
            event.parameters["lesson_version"],
            .integer(CurriculumVersion.maximum)
        )
    }

    private func assertEventually(
        _ condition: @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<1_000 {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Condition did not become true", file: file, line: line)
    }

    private func drainViewUpdates(
        _ host: UIHostingController<LearnHomeView>
    ) async {
        for _ in 0..<40 {
            host.view.layoutIfNeeded()
            await Task.yield()
        }
    }
}

private final class ControllableAnalyticsCurriculumRepository:
    CurriculumRepository,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuation: AsyncStream<CurriculumLoadEvent>.Continuation?

    var loadCount: Int {
        lock.withLock { continuation == nil ? 0 : 1 }
    }

    func load(locale _: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            lock.withLock {
                self.continuation = continuation
            }
        }
    }

    func yield(_ event: CurriculumLoadEvent) {
        let continuation = lock.withLock { self.continuation }
        continuation?.yield(event)
    }
}

@MainActor
private final class RecordingAnalyticsClient: AnalyticsClient {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
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

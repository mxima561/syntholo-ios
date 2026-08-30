import Foundation
import XCTest
@testable import Syntholo

@MainActor
final class FirstLessonHandoffCoordinatorTests: XCTestCase {
    func testSuccessfulResolutionInstallsExactRouteBeforeCompletion() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let expectedReference = try expectedFirstLessonReference(in: snapshot)
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(.fresh(snapshot), to: 0)
        await assertEventually {
            fixture.store.state == .ready(snapshot, freshness: .fresh)
                && !fixture.store.isLoadActive
        }

        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.probe.callCount, 1)
        XCTAssertEqual(
            fixture.probe.pathAtCompletion,
            [.lesson(expectedReference)]
        )
        XCTAssertEqual(fixture.probe.routeAtCompletion, .learn)
        XCTAssertEqual(
            fixture.probe.sessionStateAtCompletion,
            .firstLessonHandoff
        )
        XCTAssertEqual(fixture.router.learnPath, [.lesson(expectedReference)])
        XCTAssertEqual(fixture.session.state, .signedIn)
    }

    func testResolutionFailureRemainsAtFirstLessonHandoffAndOffersRetry() async throws {
        let locale = try CurriculumLocale("en-US")
        let fixture = makeFixture(locale: locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(
            .unavailable(error: .networkUnavailable, saved: nil),
            to: 0
        )
        await assertEventually {
            fixture.store.state == .unavailable(retryable: true)
                && !fixture.store.isLoadActive
        }

        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.handoff.presentationState, .retry)
        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertTrue(fixture.router.learnPath.isEmpty)
        XCTAssertEqual(fixture.probe.callCount, 0)
    }

    func testDuplicatePreviewTapsStartExactlyOneCurriculumStream() async throws {
        let locale = try CurriculumLocale("en-US")
        let fixture = makeFixture(locale: locale)

        fixture.handoff.previewFirstLesson()
        fixture.handoff.previewFirstLesson()

        await assertEventually { fixture.repository.loadCount == 1 }
        XCTAssertEqual(fixture.repository.loadCount, 1)
        XCTAssertEqual(fixture.handoff.presentationState, .loading)
        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertEqual(fixture.probe.callCount, 0)
    }

    func testRetryStartsOneNewStreamAndSuccessfulRetryCompletesOnce() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let expectedReference = try expectedFirstLessonReference(in: snapshot)
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(
            .unavailable(error: .networkUnavailable, saved: nil),
            to: 0
        )
        await assertEventually { !fixture.store.isLoadActive }
        fixture.handoff.curriculumStoreDidChange()
        XCTAssertEqual(fixture.handoff.presentationState, .retry)

        fixture.handoff.previewFirstLesson()
        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 2 }
        fixture.repository.yield(.fresh(snapshot), to: 1)
        await assertEventually {
            fixture.store.state == .ready(snapshot, freshness: .fresh)
                && !fixture.store.isLoadActive
        }
        fixture.handoff.curriculumStoreDidChange()
        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.repository.loadCount, 2)
        XCTAssertEqual(fixture.probe.callCount, 1)
        XCTAssertEqual(fixture.router.learnPath, [.lesson(expectedReference)])
        XCTAssertEqual(fixture.session.state, .signedIn)
    }

    func testSavedSnapshotOpensPreviewWithoutWaitingForFresh() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let expectedReference = try expectedFirstLessonReference(in: snapshot)
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            fixture.store.state == .ready(snapshot, freshness: .saved)
        }
        XCTAssertTrue(fixture.store.isLoadActive)

        fixture.handoff.curriculumStoreDidChange()

        XCTAssertTrue(fixture.store.isLoadActive)
        XCTAssertEqual(fixture.probe.callCount, 1)
        XCTAssertEqual(fixture.router.learnPath, [.lesson(expectedReference)])
        XCTAssertEqual(fixture.session.state, .signedIn)
    }

    func testUpdateRequiredWithCompatibleFallbackOpensSavedPreview() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let expectedReference = try expectedFirstLessonReference(in: snapshot)
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(
            .updateRequired(requiredSchema: 2, saved: snapshot),
            to: 0
        )
        await assertEventually {
            fixture.store.state == .updateRequired(
                requiredVersion: 2,
                fallbackSnapshot: snapshot
            ) && !fixture.store.isLoadActive
        }

        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.probe.callCount, 1)
        XCTAssertEqual(fixture.router.learnPath, [.lesson(expectedReference)])
        XCTAssertEqual(fixture.session.state, .signedIn)
    }

    func testInvalidFirstLessonHierarchyFailsClosedAtHandoff() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let catalog = snapshot.catalogVersion
        let invalidSnapshot = CurriculumSnapshot(
            locale: snapshot.locale,
            catalogPointerID: snapshot.catalogPointerID,
            catalogVersion: CurriculumCatalogVersion(
                catalogVersionID: catalog.catalogVersionID,
                version: catalog.version,
                locale: catalog.locale,
                publicationState: catalog.publicationState,
                schemaVersion: catalog.schemaVersion,
                minimumClientSchemaVersion:
                    catalog.minimumClientSchemaVersion,
                programEntries: [],
                contentDigest: catalog.contentDigest,
                publishedAt: catalog.publishedAt
            ),
            programVersions: snapshot.programVersions,
            moduleVersions: snapshot.moduleVersions,
            lessonVersions: snapshot.lessonVersions,
            rubricVersions: snapshot.rubricVersions,
            assetVersions: snapshot.assetVersions
        )
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.repository.yield(.fresh(invalidSnapshot), to: 0)
        await assertEventually { !fixture.store.isLoadActive }
        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.handoff.presentationState, .retry)
        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertTrue(fixture.router.learnPath.isEmpty)
        XCTAssertEqual(fixture.probe.callCount, 0)
    }

    func testLateSuccessIsIgnoredAfterSessionLeavesHandoff() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let fixture = makeFixture(locale: snapshot.locale)

        fixture.handoff.previewFirstLesson()
        await assertEventually { fixture.repository.loadCount == 1 }
        fixture.session.transition(to: .signedOut)
        fixture.repository.yield(.fresh(snapshot), to: 0)
        await assertEventually { !fixture.store.isLoadActive }

        fixture.handoff.curriculumStoreDidChange()

        XCTAssertEqual(fixture.session.state, .signedOut)
        XCTAssertTrue(fixture.router.learnPath.isEmpty)
        XCTAssertEqual(fixture.probe.callCount, 0)
    }

    func testRestoredLearnerLandsOnLearnHomeWithoutCurriculumResolution() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let staleReference = try expectedFirstLessonReference(in: snapshot)
        let user = AuthenticatedUser(
            id: "returning-learner",
            email: nil,
            displayName: nil
        )
        let profile = LearnerProfile.make(
            user: user,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .school,
                coachMode: .supportive
            ),
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
        let session = AppSession(configurationAvailable: true)
        let onboardingCoordinator = OnboardingCoordinator(
            session: session,
            onboardingStore: OnboardingStore(repository: .memory()),
            authClient: ReturningLearnerAuthClient(user: user),
            profileRepository: ReturningLearnerProfileRepository(
                profile: profile
            ),
            analytics: NoOpAnalyticsClient()
        )
        let curriculumRepository = ControlledCurriculumRepository()
        let curriculumStore = CurriculumStore(
            repository: curriculumRepository,
            locale: snapshot.locale
        )
        let router = AppRouter()
        router.presentFirstLesson(staleReference)
        router.select(.practice)
        let dependencies = AppDependencies(
            router: router,
            onboardingCoordinator: onboardingCoordinator,
            curriculumStore: curriculumStore
        )

        await dependencies.restore()

        XCTAssertEqual(session.state, .signedIn)
        XCTAssertEqual(router.selectedRoute, .learn)
        XCTAssertTrue(router.learnPath.isEmpty)
        XCTAssertEqual(curriculumRepository.loadCount, 0)
    }

    func testOnboardingSourcesHaveNoCurriculumOrFirestoreInfrastructureCoupling() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let onboardingDirectory = repositoryRoot
            .appendingPathComponent("Syntholo/Features/Onboarding", isDirectory: true)
        let sourceURLs = try XCTUnwrap(
            FileManager.default.enumerator(
                at: onboardingDirectory,
                includingPropertiesForKeys: nil
            )?.allObjects as? [URL]
        )
        .filter { $0.pathExtension == "swift" }
        let forbiddenTokens = [
            "FirebaseFirestore",
            "FirestoreCurriculumRepository",
            "CurriculumRepository",
            "CurriculumStore",
            "LearnRoute",
            "LessonVersionReference",
        ]

        for sourceURL in sourceURLs {
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            for forbiddenToken in forbiddenTokens {
                XCTAssertFalse(
                    source.contains(forbiddenToken),
                    "\(sourceURL.lastPathComponent) must not couple onboarding to \(forbiddenToken)"
                )
            }
        }
    }

    private func makeFixture(locale: CurriculumLocale) -> HandoffFixture {
        let router = AppRouter()
        let repository = ControlledCurriculumRepository()
        let store = CurriculumStore(repository: repository, locale: locale)
        let session = AppSession(configurationAvailable: true)
        session.transition(to: .firstLessonHandoff)
        let probe = HandoffCompletionProbe()
        let handoff = FirstLessonHandoffCoordinator(
            router: router,
            curriculumStore: store,
            session: session,
            onComplete: {
                probe.complete(router: router, session: session)
            }
        )
        return HandoffFixture(
            router: router,
            repository: repository,
            store: store,
            session: session,
            probe: probe,
            handoff: handoff
        )
    }

    private func expectedFirstLessonReference(
        in snapshot: CurriculumSnapshot
    ) throws -> LessonVersionReference {
        let foundationsEntry = try XCTUnwrap(
            snapshot.catalogVersion.programEntries.first { entry in
                entry.programPointerID.stableIDToken == "ai-foundations"
            }
        )
        let program = try XCTUnwrap(
            snapshot.programVersions.first { program in
                program.programVersionID == foundationsEntry.programVersionID
                    && program.programID.rawValue == "ai-foundations"
            }
        )
        let firstLessonVersionID = try XCTUnwrap(program.firstLessonVersionID)
        let module = try XCTUnwrap(
            snapshot.moduleVersions.first { module in
                program.moduleVersionIDs.contains(module.moduleVersionID)
                    && module.lessonVersionIDs.contains(firstLessonVersionID)
            }
        )
        let lesson = try XCTUnwrap(
            snapshot.lessonVersions.first { lesson in
                lesson.lessonVersionID == firstLessonVersionID
            }
        )
        XCTAssertTrue(
            snapshot.rubricVersions.contains { rubric in
                rubric.rubricVersionID == lesson.rubricVersionID
            }
        )
        return LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: snapshot.catalogVersion.catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: lesson.rubricVersionID
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
}

private actor ReturningLearnerAuthClient: AuthClient {
    let user: AuthenticatedUser

    init(user: AuthenticatedUser) {
        self.user = user
    }

    func createEmailAccount(
        email _: String,
        password _: String
    ) async throws -> AuthenticatedUser {
        user
    }

    func signInWithApple(
        idToken _: String,
        rawNonce _: String,
        fullName _: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        user
    }

    func signInWithGoogle(
        idToken _: String,
        accessToken _: String
    ) async throws -> AuthenticatedUser {
        user
    }

    func restoreSession() async -> AuthenticatedUser? {
        user
    }

    func signOut() async throws {}
}

private actor ReturningLearnerProfileRepository: ProfileRepository {
    let profile: LearnerProfile

    init(profile: LearnerProfile) {
        self.profile = profile
    }

    func save(_: LearnerProfile) async throws {}

    func load(userID: String) async throws -> LearnerProfile? {
        profile.userID == userID ? profile : nil
    }
}

@MainActor
private struct HandoffFixture {
    let router: AppRouter
    let repository: ControlledCurriculumRepository
    let store: CurriculumStore
    let session: AppSession
    let probe: HandoffCompletionProbe
    let handoff: FirstLessonHandoffCoordinator
}

@MainActor
private final class HandoffCompletionProbe {
    private(set) var callCount = 0
    private(set) var pathAtCompletion: [LearnRoute] = []
    private(set) var routeAtCompletion: AppRoute?
    private(set) var sessionStateAtCompletion: AppSessionState?

    func complete(router: AppRouter, session: AppSession) {
        callCount += 1
        pathAtCompletion = router.learnPath
        routeAtCompletion = router.selectedRoute
        sessionStateAtCompletion = session.state
        session.transition(to: .signedIn)
    }
}

private final class ControlledCurriculumRepository:
    CurriculumRepository,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var continuations: [
        AsyncStream<CurriculumLoadEvent>.Continuation
    ] = []

    var loadCount: Int {
        withLock { continuations.count }
    }

    func load(locale _: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            withLock {
                continuations.append(continuation)
            }
        }
    }

    func yield(_ event: CurriculumLoadEvent, to index: Int) {
        let continuation = withLock {
            continuations.indices.contains(index)
                ? continuations[index]
                : nil
        }
        continuation?.yield(event)
    }

    @discardableResult
    private func withLock<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }
}

import Foundation
import XCTest
@testable import Syntholo

@MainActor
final class CurriculumStoreTests: XCTestCase {
    func testInitialStateIsLoadingButWorkDoesNotBeginUntilExplicitLoad() throws {
        let repository = RecordingCurriculumStoreRepository()
        let locale = try CurriculumLocale("en-US")
        let store = CurriculumStore(repository: repository, locale: locale)

        XCTAssertEqual(store.state, .loading)
        XCTAssertEqual(store.locale, locale)
        XCTAssertFalse(store.isLoadActive)
        XCTAssertEqual(repository.loadCount, 0)
    }

    func testSavedRemainsActiveUntilFreshThenBecomesCurrentAndInactive() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()

        XCTAssertTrue(store.isLoadActive)
        await assertEventually { repository.loadCount == 1 }

        repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
        }
        XCTAssertTrue(store.isLoadActive)

        repository.yield(.fresh(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }
    }

    func testEmptyMapsToEmptyAndCompletesTheActiveLoad() async throws {
        let locale = try CurriculumLocale("en-US")
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.empty, to: 0)

        await assertEventually {
            store.state == .empty && !store.isLoadActive
        }
    }

    func testUpdateRequiredPreservesItsExplicitFallback() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(
            .updateRequired(requiredSchema: 2, saved: snapshot),
            to: 0
        )

        await assertEventually {
            store.state == .updateRequired(
                requiredVersion: 2,
                fallbackSnapshot: snapshot
            ) && !store.isLoadActive
        }
    }

    func testUpdateRequiredWithoutCacheHasNoFallback() async throws {
        let locale = try CurriculumLocale("en-US")
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(
            .updateRequired(requiredSchema: 2, saved: nil),
            to: 0
        )

        await assertEventually {
            store.state == .updateRequired(
                requiredVersion: 2,
                fallbackSnapshot: nil
            ) && !store.isLoadActive
        }
    }

    func testUpdateRequiredUsesTheDisplayedSnapshotWhenEventOmitsFallback() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
        }
        repository.yield(
            .updateRequired(requiredSchema: 3, saved: nil),
            to: 0
        )

        await assertEventually {
            store.state == .updateRequired(
                requiredVersion: 3,
                fallbackSnapshot: snapshot
            ) && !store.isLoadActive
        }
    }

    func testEveryUnavailableErrorMapsToOneLearnerSafeRetryableState() async throws {
        let locale = try CurriculumLocale("en-US")
        let errors: [CurriculumRepositoryError] = [
            .notPublished,
            .contentUnavailable,
            .authenticationRequired,
            .networkUnavailable,
            .malformedDocument(path: "private/backend/path"),
            .brokenReference(id: "operator-only-reference"),
            .digestMismatch(id: "private-digest"),
            .unsupportedSchema(found: 2, supported: 1),
            .minimumClientUnsupported(required: 2, supported: 1),
            .cacheCorrupt,
            .wrongEnvironment,
            .operationCancelled,
            .backendFailure,
        ]

        for error in errors {
            let repository = RecordingCurriculumStoreRepository()
            let store = CurriculumStore(repository: repository, locale: locale)
            store.load()
            await assertEventually { repository.loadCount == 1 }

            repository.yield(.unavailable(error: error, saved: nil), to: 0)

            await assertEventually {
                store.state == .unavailable(retryable: true)
                    && !store.isLoadActive
            }
        }
    }

    func testUnavailableWithFallbackPreservesPlaceAsSavedAndEnablesRetry() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
                && store.isLoadActive
        }

        repository.yield(
            .unavailable(error: .networkUnavailable, saved: snapshot),
            to: 0
        )

        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
                && !store.isLoadActive
        }
    }

    func testFailedRefreshWithoutEventFallbackPreservesDisplayedPlaceAsSaved() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.fresh(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }

        store.refresh()
        XCTAssertEqual(store.state, .ready(snapshot, freshness: .fresh))
        XCTAssertTrue(store.isLoadActive)
        await assertEventually { repository.loadCount == 2 }
        repository.yield(
            .unavailable(error: .networkUnavailable, saved: nil),
            to: 1
        )

        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
                && !store.isLoadActive
        }
    }

    func testDuplicateLoadAndRetryAreSuppressedWhileActiveAndLoadIsInitialOnly() async throws {
        let locale = try CurriculumLocale("en-US")
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: locale)

        store.load()
        store.load()
        store.retry()
        await assertEventually { repository.loadCount == 1 }
        XCTAssertTrue(store.isLoadActive)

        repository.yield(.empty, to: 0)
        await assertEventually { !store.isLoadActive }

        store.load()
        await drainTasks()
        XCTAssertEqual(repository.loadCount, 1)

        store.retry()
        XCTAssertEqual(store.state, .loading)
        XCTAssertTrue(store.isLoadActive)
        await assertEventually { repository.loadCount == 2 }
        store.retry()
        store.load()
        await drainTasks()
        XCTAssertEqual(repository.loadCount, 2)

        repository.yield(.empty, to: 1)
        await assertEventually { !store.isLoadActive }
    }

    func testRefreshReplacesAnActiveLoadAndOnlyCurrentGenerationCanFinish() async throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: snapshot.locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
                && store.isLoadActive
        }

        store.refresh()

        XCTAssertEqual(store.state, .ready(snapshot, freshness: .saved))
        XCTAssertTrue(store.isLoadActive)
        await assertEventually {
            repository.loadCount == 2
                && repository.cancellationCount >= 1
        }

        store.refresh()
        await assertEventually {
            repository.loadCount == 3
                && repository.cancellationCount >= 2
        }
        XCTAssertTrue(store.isLoadActive)

        repository.yield(.fresh(snapshot), to: 0)
        repository.yield(.empty, to: 1)
        await drainTasks()
        XCTAssertEqual(store.state, .ready(snapshot, freshness: .saved))
        XCTAssertTrue(store.isLoadActive)

        repository.yield(.fresh(snapshot), to: 2)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }
    }

    func testLocaleReplacementCancelsOldLoadResetsPlaceAndStartsExactLocale() async throws {
        let oldLocale = try CurriculumLocale("en-US")
        let newLocale = try CurriculumLocale("fr-FR")
        let snapshot = try CurriculumTestSupport.snapshot()
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: oldLocale)

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .saved)
        }
        let oldCatalogVersionID = snapshot.catalogVersion.catalogVersionID
        store.setPinnedCatalogVersionIDs([oldCatalogVersionID])
        XCTAssertEqual(store.snapshot(for: oldCatalogVersionID), snapshot)

        store.replaceLocale(newLocale)

        XCTAssertEqual(store.locale, newLocale)
        XCTAssertEqual(store.state, .loading)
        XCTAssertTrue(store.isLoadActive)
        XCTAssertNil(store.snapshot(for: oldCatalogVersionID))
        await assertEventually {
            repository.locales == [oldLocale, newLocale]
                && repository.cancellationCount >= 1
        }

        repository.yield(.fresh(snapshot), to: 0)
        await drainTasks()
        XCTAssertEqual(store.state, .loading)
        XCTAssertTrue(store.isLoadActive)

        repository.yield(.empty, to: 1)
        await assertEventually {
            store.state == .empty && !store.isLoadActive
        }
    }

    func testReplacingWithTheSameLocaleDoesNotRestart() async throws {
        let locale = try CurriculumLocale("en-US")
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: repository, locale: locale)

        store.load()
        await assertEventually { repository.loadCount == 1 }

        store.replaceLocale(locale)
        await drainTasks()

        XCTAssertEqual(repository.loadCount, 1)
        XCTAssertEqual(repository.cancellationCount, 0)
        XCTAssertTrue(store.isLoadActive)
    }

    func testRepositoryReplacementCancelsOldEnvironmentAndUsesOnlyNewEvents() async throws {
        let locale = try CurriculumLocale("en-US")
        let snapshot = try CurriculumTestSupport.snapshot()
        let oldRepository = RecordingCurriculumStoreRepository()
        let newRepository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(repository: oldRepository, locale: locale)

        store.load()
        await assertEventually { oldRepository.loadCount == 1 }

        store.replaceRepository(newRepository, locale: locale)

        XCTAssertEqual(store.state, .loading)
        XCTAssertTrue(store.isLoadActive)
        await assertEventually {
            oldRepository.cancellationCount >= 1
                && newRepository.loadCount == 1
        }

        oldRepository.yield(.fresh(snapshot), to: 0)
        await drainTasks()
        XCTAssertEqual(store.state, .loading)

        newRepository.yield(.fresh(snapshot), to: 0)
        await assertEventually {
            store.state == .ready(snapshot, freshness: .fresh)
                && !store.isLoadActive
        }
    }

    func testDeinitCancelsTheOwnedLoadTask() async throws {
        let locale = try CurriculumLocale("en-US")
        let repository = RecordingCurriculumStoreRepository()
        weak var releasedStore: CurriculumStore?

        do {
            var store: CurriculumStore? = CurriculumStore(
                repository: repository,
                locale: locale
            )
            releasedStore = store
            store?.load()
            await assertEventually { repository.loadCount == 1 }
            store = nil
        }

        await assertEventually {
            releasedStore == nil && repository.cancellationCount >= 1
        }
    }

    func testSnapshotResolverKeepsCurrentAndPreviousCatalogThenPrunesDeterministically() async throws {
        let versionOne = try CurriculumTestSupport.snapshot()
        let versionTwo = try snapshot(versionOne, catalogVersion: 2)
        let versionThree = try snapshot(versionOne, catalogVersion: 3)
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(
            repository: repository,
            locale: versionOne.locale
        )

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(versionOne), to: 0)
        await assertEventually {
            store.state == .ready(versionOne, freshness: .saved)
        }
        repository.yield(.fresh(versionTwo), to: 0)
        await assertEventually { !store.isLoadActive }

        XCTAssertEqual(
            store.snapshot(for: versionOne.catalogVersion.catalogVersionID),
            versionOne
        )
        XCTAssertEqual(
            store.snapshot(for: versionTwo.catalogVersion.catalogVersionID),
            versionTwo
        )

        store.refresh()
        await assertEventually { repository.loadCount == 2 }
        repository.yield(.fresh(versionThree), to: 1)
        await assertEventually { !store.isLoadActive }

        XCTAssertNil(
            store.snapshot(for: versionOne.catalogVersion.catalogVersionID)
        )
        XCTAssertEqual(
            store.snapshot(for: versionTwo.catalogVersion.catalogVersionID),
            versionTwo
        )
        XCTAssertEqual(
            store.snapshot(for: versionThree.catalogVersion.catalogVersionID),
            versionThree
        )
    }

    func testPinnedRouteCatalogSurvivesNewPublicationsThenPrunesAfterUnpin() async throws {
        let versionOne = try CurriculumTestSupport.snapshot()
        let versionTwo = try snapshot(versionOne, catalogVersion: 2)
        let versionThree = try snapshot(versionOne, catalogVersion: 3)
        let versionOneID = versionOne.catalogVersion.catalogVersionID
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(
            repository: repository,
            locale: versionOne.locale
        )

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(versionOne), to: 0)
        await assertEventually {
            store.state == .ready(versionOne, freshness: .saved)
        }
        store.setPinnedCatalogVersionIDs([versionOneID])
        repository.yield(.fresh(versionTwo), to: 0)
        await assertEventually { !store.isLoadActive }

        store.refresh()
        await assertEventually { repository.loadCount == 2 }
        repository.yield(.fresh(versionThree), to: 1)
        await assertEventually { !store.isLoadActive }

        XCTAssertEqual(store.snapshot(for: versionOneID), versionOne)
        XCTAssertEqual(
            store.snapshot(for: versionTwo.catalogVersion.catalogVersionID),
            versionTwo
        )
        XCTAssertEqual(
            store.snapshot(for: versionThree.catalogVersion.catalogVersionID),
            versionThree
        )

        store.setPinnedCatalogVersionIDs([])

        XCTAssertNil(store.snapshot(for: versionOneID))
        XCTAssertEqual(
            store.snapshot(for: versionTwo.catalogVersion.catalogVersionID),
            versionTwo
        )
        XCTAssertEqual(
            store.snapshot(for: versionThree.catalogVersion.catalogVersionID),
            versionThree
        )
    }

    func testPinningCurrentCatalogDoesNotExpandTheTwoCatalogBaseline() async throws {
        let versionOne = try CurriculumTestSupport.snapshot()
        let versionTwo = try snapshot(versionOne, catalogVersion: 2)
        let versionThree = try snapshot(versionOne, catalogVersion: 3)
        let repository = RecordingCurriculumStoreRepository()
        let store = CurriculumStore(
            repository: repository,
            locale: versionOne.locale
        )

        store.load()
        await assertEventually { repository.loadCount == 1 }
        repository.yield(.saved(versionOne), to: 0)
        repository.yield(.fresh(versionTwo), to: 0)
        await assertEventually { !store.isLoadActive }
        store.setPinnedCatalogVersionIDs([
            versionTwo.catalogVersion.catalogVersionID,
        ])

        store.refresh()
        await assertEventually { repository.loadCount == 2 }
        repository.yield(.fresh(versionThree), to: 1)
        await assertEventually { !store.isLoadActive }

        XCTAssertNil(
            store.snapshot(for: versionOne.catalogVersion.catalogVersionID)
        )
        XCTAssertEqual(
            store.snapshot(for: versionTwo.catalogVersion.catalogVersionID),
            versionTwo
        )
        XCTAssertEqual(
            store.snapshot(for: versionThree.catalogVersion.catalogVersionID),
            versionThree
        )
    }

    func testLearnRoutesRetainExactImmutableIdentityAndStableHashing() throws {
        let snapshot = try CurriculumTestSupport.snapshot()
        let program = try XCTUnwrap(snapshot.programVersions.first)
        let module = try XCTUnwrap(snapshot.moduleVersions.first)
        let lesson = try XCTUnwrap(snapshot.lessonVersions.first)
        let catalogVersionID = snapshot.catalogVersion.catalogVersionID

        let programReference = ProgramVersionReference(
            locale: snapshot.locale,
            catalogVersionID: catalogVersionID,
            programVersionID: program.programVersionID
        )
        let moduleReference = ModuleVersionReference(
            locale: snapshot.locale,
            catalogVersionID: catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID
        )
        let lessonReference = LessonVersionReference(
            locale: snapshot.locale,
            catalogVersionID: catalogVersionID,
            programVersionID: program.programVersionID,
            moduleVersionID: module.moduleVersionID,
            lessonVersionID: lesson.lessonVersionID,
            rubricVersionID: lesson.rubricVersionID
        )
        let routes: [LearnRoute] = [
            .program(programReference),
            .module(moduleReference),
            .lesson(lessonReference),
        ]

        XCTAssertEqual(Set(routes).count, 3)
        XCTAssertEqual(Set(routes + routes).count, 3)
        XCTAssertEqual(routes.map(\.locale), [
            snapshot.locale,
            snapshot.locale,
            snapshot.locale,
        ])
        XCTAssertEqual(routes.map(\.catalogVersionID), [
            catalogVersionID,
            catalogVersionID,
            catalogVersionID,
        ])
        XCTAssertEqual(lessonReference.locale, snapshot.locale)
        XCTAssertEqual(lessonReference.catalogVersionID, catalogVersionID)
        XCTAssertEqual(lessonReference.programVersionID, program.programVersionID)
        XCTAssertEqual(lessonReference.moduleVersionID, module.moduleVersionID)
        XCTAssertEqual(lessonReference.lessonVersionID, lesson.lessonVersionID)
        XCTAssertEqual(lessonReference.rubricVersionID, lesson.rubricVersionID)
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

    private func snapshot(
        _ source: CurriculumSnapshot,
        catalogVersion rawVersion: Int
    ) throws -> CurriculumSnapshot {
        let version = try CurriculumVersion(rawVersion)
        let sourceCatalog = source.catalogVersion
        let catalog = CurriculumCatalogVersion(
            catalogVersionID: CurriculumCatalogVersionID(
                locale: source.locale,
                version: version
            ),
            version: version,
            locale: sourceCatalog.locale,
            publicationState: sourceCatalog.publicationState,
            schemaVersion: sourceCatalog.schemaVersion,
            minimumClientSchemaVersion: sourceCatalog.minimumClientSchemaVersion,
            programEntries: sourceCatalog.programEntries,
            contentDigest: sourceCatalog.contentDigest,
            publishedAt: sourceCatalog.publishedAt
        )
        return CurriculumSnapshot(
            locale: source.locale,
            catalogPointerID: source.catalogPointerID,
            catalogVersion: catalog,
            programVersions: source.programVersions,
            moduleVersions: source.moduleVersions,
            lessonVersions: source.lessonVersions,
            rubricVersions: source.rubricVersions,
            assetVersions: source.assetVersions
        )
    }

    private func drainTasks() async {
        for _ in 0..<20 {
            await Task.yield()
        }
    }
}

private final class RecordingCurriculumStoreRepository:
    CurriculumRepository,
    @unchecked Sendable
{
    private struct Subscription {
        let locale: CurriculumLocale
        let continuation: AsyncStream<CurriculumLoadEvent>.Continuation
    }

    private let lock = NSLock()
    private var subscriptions: [Subscription] = []
    private var cancellations = 0

    var loadCount: Int {
        withLock { subscriptions.count }
    }

    var locales: [CurriculumLocale] {
        withLock { subscriptions.map(\.locale) }
    }

    var cancellationCount: Int {
        withLock { cancellations }
    }

    func load(locale: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            continuation.onTermination = { [weak self] termination in
                guard case .cancelled = termination else {
                    return
                }
                self?.withLock {
                    self?.cancellations += 1
                }
            }
            withLock {
                subscriptions.append(
                    Subscription(locale: locale, continuation: continuation)
                )
            }
        }
    }

    func yield(_ event: CurriculumLoadEvent, to index: Int) {
        let continuation = withLock {
            subscriptions.indices.contains(index)
                ? subscriptions[index].continuation
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

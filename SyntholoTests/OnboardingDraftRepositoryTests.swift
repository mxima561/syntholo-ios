import Dispatch
import Foundation
import XCTest
@testable import Syntholo

final class OnboardingDraftRepositoryTests: XCTestCase {
    private let draft = OnboardingDraft(
        ageBand: .teen,
        goal: .workProductivity,
        experience: .intermediate,
        path: .work,
        coachMode: .strict
    )

    func testMemoryRepositorySavesLoadsAndClearsExactState() throws {
        let repository = OnboardingDraftRepository.memory()

        try repository.save(step: .coach, draft: draft)
        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.step, .coach)
        XCTAssertEqual(saved.draft, draft)

        try repository.clear()
        XCTAssertNil(try repository.load())
    }

    func testMemoryRepositoriesDoNotShareState() throws {
        let first = OnboardingDraftRepository.memory()
        let second = OnboardingDraftRepository.memory()

        try first.save(step: .experience, draft: draft)

        XCTAssertNotNil(try first.load())
        XCTAssertNil(try second.load())
    }

    func testDraftOnlySaveResumesAtPathRecommendation() throws {
        let repository = OnboardingDraftRepository.memory()
        let draftThroughExperience = OnboardingDraft(
            ageBand: .adult,
            goal: .studySmarter,
            experience: .beginner
        )

        try repository.save(draftThroughExperience)

        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.step, .pathRecommendation)
        XCTAssertEqual(
            saved.draft,
            OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .school
            )
        )
    }

    func testUserDefaultsRepositoryMatchesMemoryContract() throws {
        let defaults = try makeUserDefaults()
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "onboarding-test"
        )

        try repository.save(step: .pathRecommendation, draft: draft)
        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.step, .pathRecommendation)
        XCTAssertEqual(saved.draft, draft)

        try repository.clear()
        XCTAssertNil(try repository.load())
    }

    func testUserDefaultsKeysRemainIsolated() throws {
        let defaults = try makeUserDefaults()
        let first = OnboardingDraftRepository.userDefaults(defaults, key: "first")
        let second = OnboardingDraftRepository.userDefaults(defaults, key: "second")

        try first.save(step: .goal, draft: draft)

        XCTAssertNotNil(try first.load())
        XCTAssertNil(try second.load())
    }

    func testMalformedEnvelopeFailsClosedAndIsRemoved() throws {
        let defaults = try makeUserDefaults()
        defaults.set(Data("not-json".utf8), forKey: "malformed")
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "malformed"
        )

        XCTAssertNil(try repository.load())
        XCTAssertNil(defaults.object(forKey: "malformed"))
    }

    func testNonDataEnvelopeFailsClosedAndIsRemoved() throws {
        let defaults = try makeUserDefaults()
        defaults.set("not-data", forKey: "wrong-type")
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "wrong-type"
        )

        XCTAssertNil(try repository.load())
        XCTAssertNil(defaults.object(forKey: "wrong-type"))
    }

    func testUnsupportedEnvelopeVersionFailsClosedAndIsRemoved() throws {
        let defaults = try makeUserDefaults()
        let unsupported = Data(
            #"{"version":999,"step":"coach","draft":{"ageBand":"13-17","goal":"workProductivity","experience":"intermediate","path":"work","coachMode":"strict"}}"#.utf8
        )
        defaults.set(unsupported, forKey: "unsupported")
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "unsupported"
        )

        XCTAssertNil(try repository.load())
        XCTAssertNil(defaults.object(forKey: "unsupported"))
    }

    func testRepositoryCopiesSerializeMalformedRemovalAgainstSave() async throws {
        let defaults = CoordinatedUserDefaults()
        defaults.seed(Data("{".utf8), forKey: "coordinated")
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "coordinated"
        )
        let repositoryCopy = repository
        let savedState = OnboardingDraftRepository.State(
            step: .goal,
            draft: OnboardingDraft(ageBand: .adult)
        )

        let loadTask = Task.detached {
            try repository.load()
        }
        XCTAssertEqual(
            defaults.removeEntered.wait(timeout: .now() + 2),
            .success
        )

        let saveAttempted = DispatchSemaphore(value: 0)
        let saveTask = Task.detached {
            saveAttempted.signal()
            try repositoryCopy.save(savedState)
        }
        XCTAssertEqual(
            saveAttempted.wait(timeout: .now() + 2),
            .success
        )
        XCTAssertEqual(
            defaults.setEntered.wait(timeout: .now() + 0.5),
            .timedOut,
            "A copied repository saved while malformed cleanup was in flight"
        )

        defaults.allowRemoval.signal()
        _ = try await loadTask.value
        try await saveTask.value

        XCTAssertEqual(try repository.load(), savedState)
    }

    @MainActor
    func testStoreRestoresFreshWelcomeFromMalformedEnvelope() async throws {
        let defaults = try makeUserDefaults()
        defaults.set(Data("{".utf8), forKey: "store-malformed")
        let repository = OnboardingDraftRepository.userDefaults(
            defaults,
            key: "store-malformed"
        )
        let store = OnboardingStore(repository: repository)

        await store.restore()

        XCTAssertEqual(store.step, .welcome)
        XCTAssertEqual(store.draft, OnboardingDraft())
        XCTAssertNil(store.error)
    }

    @MainActor
    func testStoreFailsClosedFromLogicallyInvalidAccountState() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(
            step: .account,
            draft: OnboardingDraft(goal: .buildWithAI)
        )
        let store = OnboardingStore(repository: repository)

        await store.restore()

        XCTAssertEqual(store.step, .welcome)
        XCTAssertEqual(store.draft, OnboardingDraft())
        XCTAssertNil(try repository.load())
    }

    private func makeUserDefaults() throws -> UserDefaults {
        let suiteName = "OnboardingDraftRepositoryTests.\(UUID().uuidString)"
        return try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }
}

private final class CoordinatedUserDefaults: UserDefaults, @unchecked Sendable {
    let removeEntered = DispatchSemaphore(value: 0)
    let allowRemoval = DispatchSemaphore(value: 0)
    let setEntered = DispatchSemaphore(value: 0)

    private let storageLock = NSLock()
    private var storage: [String: Any] = [:]

    override func object(forKey defaultName: String) -> Any? {
        storageLock.withLock { storage[defaultName] }
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        setEntered.signal()
        storageLock.withLock {
            storage[defaultName] = value
        }
    }

    override func removeObject(forKey defaultName: String) {
        removeEntered.signal()
        allowRemoval.wait()
        _ = storageLock.withLock {
            storage.removeValue(forKey: defaultName)
        }
    }

    func seed(_ value: Any, forKey key: String) {
        storageLock.withLock {
            storage[key] = value
        }
    }
}

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
        XCTAssertEqual(saved.draft, draftThroughExperience)
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

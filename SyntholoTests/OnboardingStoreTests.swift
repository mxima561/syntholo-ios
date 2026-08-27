import XCTest
@testable import Syntholo

@MainActor
final class OnboardingStoreTests: XCTestCase {
    private let completeDraft = OnboardingDraft(
        ageBand: .adult,
        goal: .buildWithAI,
        experience: .advanced,
        path: .build,
        coachMode: .socratic
    )

    func testForwardFlowRequiresSelectionsAndReachesAccount() {
        let store = OnboardingStore(repository: .memory())

        XCTAssertEqual(store.step, .welcome)
        store.advance()
        XCTAssertEqual(store.step, .age)

        store.advance()
        XCTAssertEqual(store.step, .age)
        store.selectAgeBand(.teen)
        store.advance()
        XCTAssertEqual(store.step, .goal)

        store.advance()
        XCTAssertEqual(store.step, .goal)
        store.selectGoal(.createContent)
        store.advance()
        XCTAssertEqual(store.step, .experience)

        store.advance()
        XCTAssertEqual(store.step, .experience)
        store.selectExperience(.intermediate)
        store.advance()
        XCTAssertEqual(store.step, .pathRecommendation)
        XCTAssertEqual(store.draft.path, .creation)

        store.advance()
        XCTAssertEqual(store.step, .coach)
        store.selectCoachMode(.funny)
        store.advance()

        XCTAssertEqual(store.step, .account)
        XCTAssertTrue(store.draft.isReadyForAccount)
        XCTAssertEqual(store.draft.coachMode, .funny)
    }

    func testPathRecommendationCanBeChangedBeforeAdvancing() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .pathRecommendation, draft: completeDraft)
        let store = OnboardingStore(repository: repository)

        await store.restore()
        store.selectPath(.work)
        store.advance()

        XCTAssertEqual(store.step, .coach)
        XCTAssertEqual(store.draft.path, .work)
    }

    func testUnderThirteenNeverAdvancesToAccount() async throws {
        let repository = OnboardingDraftRepository.memory()
        let store = OnboardingStore(repository: repository)

        store.rejectUnderThirteen()
        store.selectAgeBand(.adult)
        store.selectGoal(.buildWithAI)
        store.selectExperience(.advanced)
        store.selectPath(.build)
        store.selectCoachMode(.strict)
        store.advance()
        store.beginProfileSave()

        XCTAssertEqual(store.step, .ageRestricted)
        XCTAssertNil(store.draft.ageBand)
        XCTAssertFalse(store.draft.isReadyForAccount)
        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.step, .ageRestricted)
        XCTAssertEqual(saved.draft, OnboardingDraft())

        let restoredStore = OnboardingStore(repository: repository)
        await restoredStore.restore()
        XCTAssertEqual(restoredStore.step, .ageRestricted)
        XCTAssertNil(restoredStore.draft.ageBand)
    }

    func testBackNavigationIsDeterministicBeforeAccount() async throws {
        let expectedPreviousSteps: [(OnboardingStep, OnboardingStep)] = [
            (.age, .welcome),
            (.ageRestricted, .age),
            (.goal, .age),
            (.experience, .goal),
            (.pathRecommendation, .experience),
            (.coach, .pathRecommendation),
        ]

        for (current, expected) in expectedPreviousSteps {
            let repository = OnboardingDraftRepository.memory()
            let draft = current == .ageRestricted ? OnboardingDraft() : completeDraft
            try repository.save(step: current, draft: draft)
            let store = OnboardingStore(repository: repository)
            await store.restore()

            store.goBack()

            XCTAssertEqual(store.step, expected, "Wrong predecessor for \(current)")
            XCTAssertEqual(try repository.load()?.step, expected)
        }
    }

    func testBackNavigationIsDisabledAtAndAfterAccountBoundary() async throws {
        for step in [OnboardingStep.account, .savingProfile, .firstLessonHandoff] {
            let repository = OnboardingDraftRepository.memory()
            try repository.save(step: step, draft: completeDraft)
            let store = OnboardingStore(repository: repository)
            await store.restore()

            XCTAssertFalse(store.canGoBack)
            store.goBack()

            XCTAssertEqual(store.step, step)
        }
    }

    func testEverySelectionAndTransitionPersistsExactState() async {
        let repository = OnboardingDraftRepository.memory()
        let store = OnboardingStore(repository: repository)

        store.advance()
        await assertRestored(repository, step: .age, draft: OnboardingDraft())

        store.selectAgeBand(.adult)
        await assertRestored(
            repository,
            step: .age,
            draft: OnboardingDraft(ageBand: .adult)
        )

        store.advance()
        store.selectGoal(.studySmarter)
        await assertRestored(
            repository,
            step: .goal,
            draft: OnboardingDraft(ageBand: .adult, goal: .studySmarter)
        )

        store.advance()
        store.selectExperience(.beginner)
        await assertRestored(
            repository,
            step: .experience,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner
            )
        )

        store.advance()
        await assertRestored(
            repository,
            step: .pathRecommendation,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .school
            )
        )

        store.selectPath(.creation)
        await assertRestored(
            repository,
            step: .pathRecommendation,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .creation
            )
        )

        store.advance()
        store.selectCoachMode(.chill)
        await assertRestored(
            repository,
            step: .coach,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .creation,
                coachMode: .chill
            )
        )

        store.advance()
        await assertRestored(
            repository,
            step: .account,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .creation,
                coachMode: .chill
            )
        )
    }

    func testResumeRestoresDraftAndExactStep() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .pathRecommendation, draft: completeDraft)
        let store = OnboardingStore(repository: repository)

        await store.restore()

        XCTAssertEqual(store.step, .pathRecommendation)
        XCTAssertEqual(store.draft, completeDraft)
    }

    func testResetClearsPersistedProgress() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .coach, draft: completeDraft)
        let store = OnboardingStore(repository: repository)
        await store.restore()

        store.reset()

        XCTAssertEqual(store.step, .welcome)
        XCTAssertEqual(store.draft, OnboardingDraft())
        XCTAssertNil(try repository.load())
    }

    func testProfileSaveFailureAndRetryRetainDraft() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .account, draft: completeDraft)
        let store = OnboardingStore(repository: repository)
        await store.restore()

        store.beginProfileSave()
        XCTAssertEqual(store.step, .savingProfile)
        XCTAssertEqual(try repository.load()?.step, .savingProfile)
        store.profileSaveFailed()

        XCTAssertEqual(store.step, .account)
        XCTAssertEqual(store.error, .profileSaveFailed)
        XCTAssertEqual(store.draft, completeDraft)
        XCTAssertTrue(store.canRetryProfileSave)
        XCTAssertEqual(try repository.load()?.step, .account)
        XCTAssertEqual(try repository.load()?.draft, completeDraft)

        store.retryProfileSave()

        XCTAssertEqual(store.step, .savingProfile)
        XCTAssertNil(store.error)
        XCTAssertEqual(store.draft, completeDraft)
        let saved = try XCTUnwrap(repository.load())
        XCTAssertEqual(saved.step, .savingProfile)
        XCTAssertEqual(saved.draft, completeDraft)
    }

    func testProfileSaveSuccessClearsStoredDraftAtHandoff() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .savingProfile, draft: completeDraft)
        let store = OnboardingStore(repository: repository)
        await store.restore()

        store.profileSaveSucceeded()

        XCTAssertEqual(store.step, .firstLessonHandoff)
        XCTAssertEqual(store.draft, completeDraft)
        XCTAssertNil(try repository.load())
    }

    private func assertRestored(
        _ repository: OnboardingDraftRepository,
        step: OnboardingStep,
        draft: OnboardingDraft,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let restoredStore = OnboardingStore(repository: repository)
        await restoredStore.restore()
        XCTAssertEqual(restoredStore.step, step, file: file, line: line)
        XCTAssertEqual(restoredStore.draft, draft, file: file, line: line)
    }
}

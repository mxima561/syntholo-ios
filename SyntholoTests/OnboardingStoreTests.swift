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

        store.selectAgeBand(.teen)
        XCTAssertEqual(store.step, .goal)

        store.selectGoal(.createContent)
        XCTAssertEqual(store.step, .experience)

        store.selectExperience(.intermediate)
        XCTAssertEqual(store.step, .pathRecommendation)
        XCTAssertEqual(store.draft.path, .creation)

        store.selectPath(.creation)
        XCTAssertEqual(store.step, .coach)
        store.selectCoachMode(.funny)

        XCTAssertEqual(store.step, .account)
        XCTAssertTrue(store.draft.isReadyForAccount)
        XCTAssertEqual(store.draft.coachMode, .funny)
    }

    func testPathRecommendationCanBeChangedBeforeContinuing() async throws {
        let recommendedDraft = OnboardingDraft(
            ageBand: .adult,
            goal: .buildWithAI,
            experience: .advanced,
            path: .build
        )
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .pathRecommendation, draft: recommendedDraft)
        let store = OnboardingStore(repository: repository)

        await store.restore()
        store.selectPath(.work)

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

    func testAgeRestrictedStateIsTerminal() async throws {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .ageRestricted, draft: OnboardingDraft())
        let store = OnboardingStore(repository: repository)
        await store.restore()

        XCTAssertFalse(store.canGoBack)
        store.goBack()

        XCTAssertEqual(store.step, .ageRestricted)
        XCTAssertEqual(store.draft, OnboardingDraft())
        XCTAssertEqual(try repository.load()?.step, .ageRestricted)
        XCTAssertEqual(try repository.load()?.draft, OnboardingDraft())
    }

    func testBackNavigationIsDeterministicBeforeAccount() async throws {
        let expectedPreviousSteps: [(
            current: OnboardingStep,
            draft: OnboardingDraft,
            previous: OnboardingStep,
            previousDraft: OnboardingDraft
        )] = [
            (.age, OnboardingDraft(), .welcome, OnboardingDraft()),
            (
                .goal,
                OnboardingDraft(ageBand: .adult),
                .age,
                OnboardingDraft()
            ),
            (
                .experience,
                OnboardingDraft(ageBand: .adult, goal: .buildWithAI),
                .goal,
                OnboardingDraft(ageBand: .adult)
            ),
            (
                .pathRecommendation,
                OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced,
                    path: .build
                ),
                .experience,
                OnboardingDraft(ageBand: .adult, goal: .buildWithAI)
            ),
            (
                .coach,
                OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced,
                    path: .build
                ),
                .pathRecommendation,
                OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced,
                    path: .build
                )
            ),
        ]

        for item in expectedPreviousSteps {
            let repository = OnboardingDraftRepository.memory()
            try repository.save(step: item.current, draft: item.draft)
            let store = OnboardingStore(repository: repository)
            await store.restore()

            store.goBack()

            XCTAssertEqual(
                store.step,
                item.previous,
                "Wrong predecessor for \(item.current)"
            )
            XCTAssertEqual(store.draft, item.previousDraft)
            XCTAssertEqual(try repository.load()?.step, item.previous)
            XCTAssertEqual(try repository.load()?.draft, item.previousDraft)
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
            step: .goal,
            draft: OnboardingDraft(ageBand: .adult)
        )

        store.selectGoal(.studySmarter)
        await assertRestored(
            repository,
            step: .experience,
            draft: OnboardingDraft(ageBand: .adult, goal: .studySmarter)
        )

        store.selectExperience(.beginner)
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
            step: .coach,
            draft: OnboardingDraft(
                ageBand: .adult,
                goal: .studySmarter,
                experience: .beginner,
                path: .creation
            )
        )

        store.selectCoachMode(.chill)
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
        let recommendedDraft = OnboardingDraft(
            ageBand: .adult,
            goal: .buildWithAI,
            experience: .advanced,
            path: .build
        )
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .pathRecommendation, draft: recommendedDraft)
        let store = OnboardingStore(repository: repository)

        await store.restore()

        XCTAssertEqual(store.step, .pathRecommendation)
        XCTAssertEqual(store.draft, recommendedDraft)
    }

    func testResetClearsPersistedProgress() async throws {
        let coachDraft = OnboardingDraft(
            ageBand: .adult,
            goal: .buildWithAI,
            experience: .advanced,
            path: .build
        )
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .coach, draft: coachDraft)
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

    func testImpossibleCanonicalSnapshotsFailClosedToWelcome() async throws {
        let impossibleStates: [OnboardingDraftRepository.State] = [
            .init(step: .welcome, draft: OnboardingDraft(ageBand: .adult)),
            .init(step: .age, draft: OnboardingDraft(ageBand: .adult)),
            .init(step: .ageRestricted, draft: OnboardingDraft(goal: .buildWithAI)),
            .init(
                step: .goal,
                draft: OnboardingDraft(ageBand: .adult, goal: .buildWithAI)
            ),
            .init(
                step: .experience,
                draft: OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced
                )
            ),
            .init(
                step: .pathRecommendation,
                draft: OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced
                )
            ),
            .init(
                step: .pathRecommendation,
                draft: OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced,
                    path: .build,
                    coachMode: .strict
                )
            ),
            .init(
                step: .coach,
                draft: OnboardingDraft(
                    ageBand: .adult,
                    goal: .buildWithAI,
                    experience: .advanced,
                    path: .build,
                    coachMode: .strict
                )
            ),
        ]

        for impossible in impossibleStates {
            let repository = OnboardingDraftRepository.memory()
            try repository.save(impossible)
            let store = OnboardingStore(repository: repository)

            await store.restore()

            XCTAssertEqual(store.step, .welcome, "Accepted \(impossible)")
            XCTAssertEqual(store.draft, OnboardingDraft())
            XCTAssertNil(try repository.load())
        }
    }

    func testEveryCanonicalReachableStateRestoresExactly() async throws {
        let age = OnboardingDraft(ageBand: .teen)
        let goal = OnboardingDraft(ageBand: .teen, goal: .createContent)
        let recommended = OnboardingDraft(
            ageBand: .teen,
            goal: .createContent,
            experience: .intermediate,
            path: .creation
        )
        let selectedCoach = OnboardingDraft(
            ageBand: .teen,
            goal: .createContent,
            experience: .intermediate,
            path: .creation,
            coachMode: .socratic
        )
        let validStates: [OnboardingDraftRepository.State] = [
            .init(step: .welcome, draft: OnboardingDraft()),
            .init(step: .age, draft: OnboardingDraft()),
            .init(step: .ageRestricted, draft: OnboardingDraft()),
            .init(step: .goal, draft: age),
            .init(step: .experience, draft: goal),
            .init(step: .pathRecommendation, draft: recommended),
            .init(step: .coach, draft: recommended),
            .init(step: .account, draft: recommended),
            .init(step: .account, draft: selectedCoach),
            .init(step: .savingProfile, draft: selectedCoach),
            .init(step: .firstLessonHandoff, draft: selectedCoach),
        ]

        for valid in validStates {
            let repository = OnboardingDraftRepository.memory()
            try repository.save(valid)
            let store = OnboardingStore(repository: repository)

            await store.restore()

            XCTAssertEqual(store.step, valid.step)
            XCTAssertEqual(store.draft, valid.draft)
        }
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

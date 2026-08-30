import XCTest
@testable import Syntholo

final class OnboardingModelsTests: XCTestCase {
    func testAgeBandRawValuesMatchSupportedAgeRanges() {
        XCTAssertEqual(AgeBand.teen.rawValue, "13-17")
        XCTAssertEqual(AgeBand.adult.rawValue, "18+")
    }

    func testLearnerGoalRawValuesMatchFrozenContract() {
        XCTAssertEqual(
            LearnerGoal.allCases.map(\.rawValue),
            ["studySmarter", "workProductivity", "createContent", "buildWithAI"]
        )
    }

    func testExperienceLevelRawValuesMatchFrozenContract() {
        XCTAssertEqual(
            ExperienceLevel.allCases.map(\.rawValue),
            ["beginner", "intermediate", "advanced"]
        )
    }

    func testLearningPathRawValuesContainOnlySelectableSpecializations() {
        XCTAssertEqual(
            LearningPath.allCases.map(\.rawValue),
            ["school", "work", "creation", "build"]
        )
    }

    func testCoachModeRawValuesMatchFrozenContract() {
        XCTAssertEqual(
            CoachMode.allCases.map(\.rawValue),
            ["supportive", "funny", "strict", "chill", "socratic"]
        )
    }

    func testDefaultDraftUsesSupportiveCoach() {
        XCTAssertEqual(OnboardingDraft().coachMode, .supportive)
    }

    func testDraftIsReadyOnlyWhenAllRequiredSelectionsArePresent() {
        XCTAssertTrue(
            OnboardingDraft(
                ageBand: .adult,
                goal: .buildWithAI,
                experience: .advanced,
                path: .build
            ).isReadyForAccount
        )

        XCTAssertFalse(OnboardingDraft(goal: .buildWithAI, experience: .advanced, path: .build).isReadyForAccount)
        XCTAssertFalse(OnboardingDraft(ageBand: .adult, experience: .advanced, path: .build).isReadyForAccount)
        XCTAssertFalse(OnboardingDraft(ageBand: .adult, goal: .buildWithAI, path: .build).isReadyForAccount)
        XCTAssertFalse(OnboardingDraft(ageBand: .adult, goal: .buildWithAI, experience: .advanced).isReadyForAccount)
    }

    func testDraftRoundTripsThroughCodablePersistence() throws {
        let draft = OnboardingDraft(
            ageBand: .teen,
            goal: .createContent,
            experience: .intermediate,
            path: .creation,
            coachMode: .socratic
        )

        let data = try JSONEncoder().encode(draft)

        XCTAssertEqual(try JSONDecoder().decode(OnboardingDraft.self, from: data), draft)
    }
}

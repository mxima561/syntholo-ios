import XCTest
@testable import Syntholo

final class PathRecommenderTests: XCTestCase {
    func testSchoolGoalRecommendsSchoolPath() {
        XCTAssertEqual(
            PathRecommender.recommend(goal: .studySmarter, experience: .beginner),
            .school
        )
    }

    func testEveryGoalProducesItsSpecialization() {
        let expectedPaths: [LearnerGoal: LearningPath] = [
            .studySmarter: .school,
            .workProductivity: .work,
            .createContent: .creation,
            .buildWithAI: .build,
        ]

        for goal in LearnerGoal.allCases {
            XCTAssertEqual(
                PathRecommender.recommend(goal: goal, experience: .beginner),
                expectedPaths[goal]
            )
        }
    }

    func testExperienceDoesNotOverrideExplicitGoal() {
        for experience in ExperienceLevel.allCases {
            XCTAssertEqual(
                PathRecommender.recommend(goal: .workProductivity, experience: experience),
                .work
            )
        }
    }
}

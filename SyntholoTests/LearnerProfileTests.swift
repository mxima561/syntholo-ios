import Foundation
import XCTest
@testable import Syntholo

final class LearnerProfileTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testTeenProfileIsUndiscoverableByDefault() {
        let profile = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .teen),
            now: now
        )

        XCTAssertFalse(profile.isDiscoverable)
    }

    func testAdultProfileStillRequiresExplicitDiscoveryConsent() {
        let profile = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .adult),
            now: now
        )

        XCTAssertFalse(profile.isDiscoverable)
    }

    func testProfileKeepsStableIdentitySchemaAndOnboardingSelections() {
        let profile = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .adult),
            now: now
        )

        XCTAssertEqual(profile.userID, "firebase-user-123")
        XCTAssertEqual(profile.schemaVersion, 1)
        XCTAssertEqual(profile.ageBand, .adult)
        XCTAssertEqual(profile.goal, .studySmarter)
        XCTAssertEqual(profile.experience, .intermediate)
        XCTAssertEqual(profile.selectedPath, .school)
        XCTAssertEqual(profile.coachMode, .socratic)
        XCTAssertEqual(profile.createdAt, now)
        XCTAssertEqual(profile.updatedAt, now)
    }

    func testProfileEnrollsInFoundationsBeforeChosenSpecialization() {
        let profile = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .teen),
            now: now
        )

        XCTAssertEqual(
            profile.enrolledProgramIDs,
            ["ai-foundations", "ai-school"]
        )
    }

    func testPublicHandleIsStableAndDoesNotExposePrivateIdentity() {
        let first = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .adult),
            now: now
        )
        let second = LearnerProfile.make(
            user: user,
            draft: draft(ageBand: .teen),
            now: now.addingTimeInterval(60)
        )

        XCTAssertEqual(first.handle, second.handle)
        XCTAssertTrue(
            first.handle.range(
                of: #"^learner-[a-f0-9]{20}$"#,
                options: .regularExpression
            ) != nil
        )
        XCTAssertFalse(first.handle.contains(user.id))
        XCTAssertFalse(first.handle.contains("learner@example.com"))
        XCTAssertFalse(first.handle.contains("Taylor"))
    }

    private var user: AuthenticatedUser {
        AuthenticatedUser(
            id: "firebase-user-123",
            email: "learner@example.com",
            displayName: "Taylor Learner"
        )
    }

    private func draft(ageBand: AgeBand) -> OnboardingDraft {
        OnboardingDraft(
            ageBand: ageBand,
            goal: .studySmarter,
            experience: .intermediate,
            path: .school,
            coachMode: .socratic
        )
    }
}

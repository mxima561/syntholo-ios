import Foundation
import XCTest
@testable import Syntholo

final class ProfileRepositoryContractTests: XCTestCase {
    func testSaveThenLoadPreservesCompleteProfile() async throws {
        let repository = RecordingProfileRepository()
        let profile = makeProfile()

        try await repository.save(profile)

        let loaded = try await repository.load(userID: profile.userID)
        XCTAssertEqual(loaded, profile)
    }

    func testRetryWithSameUIDDoesNotDuplicateProfileRecord() async throws {
        let repository = RecordingProfileRepository()
        let profile = makeProfile()

        try await repository.save(profile)
        try await repository.save(profile)

        let recordCount = await repository.recordCount
        let loaded = try await repository.load(userID: "firebase-user-123")
        XCTAssertEqual(recordCount, 1)
        XCTAssertEqual(loaded, profile)
    }

    private func makeProfile() -> LearnerProfile {
        LearnerProfile.make(
            user: AuthenticatedUser(
                id: "firebase-user-123",
                email: "learner@example.com",
                displayName: "Taylor Learner"
            ),
            draft: OnboardingDraft(
                ageBand: .teen,
                goal: .buildWithAI,
                experience: .advanced,
                path: .build,
                coachMode: .strict
            ),
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}

private actor RecordingProfileRepository: ProfileRepository {
    private var profiles: [String: LearnerProfile] = [:]

    var recordCount: Int {
        profiles.count
    }

    func save(_ profile: LearnerProfile) async throws {
        profiles[profile.userID] = profile
    }

    func load(userID: String) async throws -> LearnerProfile? {
        profiles[userID]
    }
}

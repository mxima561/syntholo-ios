import CryptoKit
import Foundation

struct LearnerProfile: Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let foundationsProgramID = "ai-foundations"

    let userID: String
    let email: String?
    let displayName: String?
    let ageBand: AgeBand
    let goal: LearnerGoal
    let experience: ExperienceLevel
    let selectedPath: LearningPath
    let coachMode: CoachMode
    let enrolledProgramIDs: [String]
    let handle: String
    let isDiscoverable: Bool
    let schemaVersion: Int
    let createdAt: Date
    let updatedAt: Date

    static func make(
        user: AuthenticatedUser,
        draft: OnboardingDraft,
        now: Date
    ) -> LearnerProfile {
        guard !user.id.isEmpty,
              let ageBand = draft.ageBand,
              let goal = draft.goal,
              let experience = draft.experience,
              let selectedPath = draft.path else {
            preconditionFailure("A learner profile requires a complete onboarding draft")
        }

        return LearnerProfile(
            userID: user.id,
            email: user.email,
            displayName: user.displayName,
            ageBand: ageBand,
            goal: goal,
            experience: experience,
            selectedPath: selectedPath,
            coachMode: draft.coachMode,
            enrolledProgramIDs: [
                foundationsProgramID,
                specializationProgramID(for: selectedPath),
            ],
            handle: opaqueHandle(for: user.id),
            isDiscoverable: false,
            schemaVersion: currentSchemaVersion,
            createdAt: now,
            updatedAt: now
        )
    }

    static func specializationProgramID(for path: LearningPath) -> String {
        "ai-\(path.rawValue)"
    }

    private static func opaqueHandle(for userID: String) -> String {
        let digest = SHA256.hash(data: Data(userID.utf8))
        let hexadecimal = digest.map { String(format: "%02x", $0) }.joined()
        return "learner-\(hexadecimal.prefix(20))"
    }
}

enum AgeBand: String, Codable, Sendable {
    case teen = "13-17"
    case adult = "18+"
}

enum LearnerGoal: String, CaseIterable, Codable, Sendable {
    case studySmarter
    case workProductivity
    case createContent
    case buildWithAI
}

enum ExperienceLevel: String, CaseIterable, Codable, Sendable {
    case beginner
    case intermediate
    case advanced
}

enum LearningPath: String, CaseIterable, Codable, Sendable {
    case school
    case work
    case creation
    case build
}

enum CoachMode: String, CaseIterable, Codable, Sendable {
    case supportive
    case funny
    case strict
    case chill
    case socratic
}

struct OnboardingDraft: Codable, Equatable, Sendable {
    var ageBand: AgeBand?
    var goal: LearnerGoal?
    var experience: ExperienceLevel?
    var path: LearningPath?
    var coachMode: CoachMode

    init(
        ageBand: AgeBand? = nil,
        goal: LearnerGoal? = nil,
        experience: ExperienceLevel? = nil,
        path: LearningPath? = nil,
        coachMode: CoachMode = .supportive
    ) {
        self.ageBand = ageBand
        self.goal = goal
        self.experience = experience
        self.path = path
        self.coachMode = coachMode
    }

    var isReadyForAccount: Bool {
        ageBand != nil && goal != nil && experience != nil && path != nil
    }
}

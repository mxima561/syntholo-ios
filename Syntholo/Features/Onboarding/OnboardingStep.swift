enum OnboardingStep: String, Codable, Sendable {
    case welcome
    case age
    case ageRestricted
    case goal
    case experience
    case pathRecommendation
    case coach
    case account
    case savingProfile
    case firstLessonHandoff
}

enum OnboardingError: Equatable, Sendable {
    case profileSaveFailed
}

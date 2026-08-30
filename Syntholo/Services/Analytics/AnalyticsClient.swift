enum AuthenticationProvider: String, CaseIterable, Sendable {
    case apple
    case google
    case password
}

enum AnalyticsEventName: String, CaseIterable, Sendable {
    case onboardingStarted = "onboarding_started"
    case onboardingCompleted = "onboarding_completed"
    case ageConfirmed = "age_confirmed"
    case goalSelected = "goal_selected"
    case pathRecommended = "path_recommended"
    case pathSelected = "path_selected"
    case coachModeSelected = "coach_mode_selected"
    case accountCreated = "account_created"
    case loginCompleted = "login_completed"
}

enum AnalyticsParameterKey: String, Sendable {
    case goal
    case path
    case coachMode = "coach_mode"
    case authenticationProvider = "auth_provider"
    case restoredSession = "restored_session"
}

enum AnalyticsParameter: Equatable, Sendable {
    case goal(LearnerGoal)
    case path(LearningPath)
    case coachMode(CoachMode)
    case authenticationProvider(AuthenticationProvider)
    case restoredSession(Bool)

    var key: AnalyticsParameterKey {
        switch self {
        case .goal:
            .goal
        case .path:
            .path
        case .coachMode:
            .coachMode
        case .authenticationProvider:
            .authenticationProvider
        case .restoredSession:
            .restoredSession
        }
    }
}

struct AnalyticsPayload: Equatable, Sendable {
    let name: AnalyticsEventName
    let parameters: [AnalyticsParameter]
}

enum AnalyticsEvent: Equatable, Sendable {
    case onboardingStarted
    case onboardingCompleted
    case ageConfirmed
    case goalSelected(LearnerGoal)
    case pathRecommended(LearningPath)
    case pathSelected(LearningPath)
    case coachModeSelected(CoachMode)
    case accountCreated(AuthenticationProvider)
    case loginCompleted(restoredSession: Bool)

    var payload: AnalyticsPayload {
        switch self {
        case .onboardingStarted:
            AnalyticsPayload(name: .onboardingStarted, parameters: [])
        case .onboardingCompleted:
            AnalyticsPayload(name: .onboardingCompleted, parameters: [])
        case .ageConfirmed:
            AnalyticsPayload(name: .ageConfirmed, parameters: [])
        case let .goalSelected(goal):
            AnalyticsPayload(
                name: .goalSelected,
                parameters: [.goal(goal)]
            )
        case let .pathRecommended(path):
            AnalyticsPayload(
                name: .pathRecommended,
                parameters: [.path(path)]
            )
        case let .pathSelected(path):
            AnalyticsPayload(
                name: .pathSelected,
                parameters: [.path(path)]
            )
        case let .coachModeSelected(mode):
            AnalyticsPayload(
                name: .coachModeSelected,
                parameters: [.coachMode(mode)]
            )
        case let .accountCreated(provider):
            AnalyticsPayload(
                name: .accountCreated,
                parameters: [.authenticationProvider(provider)]
            )
        case let .loginCompleted(restoredSession):
            AnalyticsPayload(
                name: .loginCompleted,
                parameters: [.restoredSession(restoredSession)]
            )
        }
    }
}

@MainActor
protocol AnalyticsClient: Sendable {
    func log(_ event: AnalyticsEvent)
}

struct NoOpAnalyticsClient: AnalyticsClient {
    func log(_: AnalyticsEvent) {}
}

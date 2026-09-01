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
    case programViewed = "program_viewed"
    case moduleViewed = "module_viewed"
    case lessonViewed = "lesson_viewed"
}

enum AnalyticsParameterKey: String, CaseIterable, Sendable {
    case goal
    case path
    case coachMode = "coach_mode"
    case authenticationProvider = "auth_provider"
    case restoredSession = "restored_session"
    case locale
    case catalogVersion = "catalog_version"
    case programID = "program_id"
    case programVersion = "program_version"
    case moduleID = "module_id"
    case moduleVersion = "module_version"
    case lessonID = "lesson_id"
    case lessonVersion = "lesson_version"
    case rubricID = "rubric_id"
    case rubricVersion = "rubric_version"
    case curriculumSource = "content_source"
    case durationBucket = "duration_bucket"
}

enum CurriculumDurationBucket: String, CaseIterable, Sendable {
    // These reporting buckets cover the schema-v1 validated 1...180 minutes.
    case minutes1To5 = "1_5_minutes"
    case minutes6To10 = "6_10_minutes"
    case minutes11To20 = "11_20_minutes"
    case minutes21To40 = "21_40_minutes"
    case minutes41To180 = "41_180_minutes"

    init?(expectedMinutes: Int) {
        switch expectedMinutes {
        case 1...5:
            self = .minutes1To5
        case 6...10:
            self = .minutes6To10
        case 11...20:
            self = .minutes11To20
        case 21...40:
            self = .minutes21To40
        case 41...180:
            self = .minutes41To180
        default:
            return nil
        }
    }
}

enum CurriculumAnalyticsSource: String, CaseIterable, Sendable {
    case saved
    case fresh
}

struct ProgramViewAnalyticsContext: Equatable, Sendable {
    let locale: CurriculumLocale
    let catalogVersion: CurriculumVersion
    let programID: CurriculumStableID
    let programVersion: CurriculumVersion
    let source: CurriculumAnalyticsSource
}

struct ModuleViewAnalyticsContext: Equatable, Sendable {
    let locale: CurriculumLocale
    let catalogVersion: CurriculumVersion
    let programID: CurriculumStableID
    let programVersion: CurriculumVersion
    let moduleID: CurriculumStableID
    let moduleVersion: CurriculumVersion
    let source: CurriculumAnalyticsSource
}

struct LessonViewAnalyticsContext: Equatable, Sendable {
    let locale: CurriculumLocale
    let catalogVersion: CurriculumVersion
    let programID: CurriculumStableID
    let programVersion: CurriculumVersion
    let moduleID: CurriculumStableID
    let moduleVersion: CurriculumVersion
    let lessonID: CurriculumStableID
    let lessonVersion: CurriculumVersion
    let rubricID: CurriculumStableID
    let rubricVersion: CurriculumVersion
    let source: CurriculumAnalyticsSource
    let durationBucket: CurriculumDurationBucket
}

enum AnalyticsParameter: Equatable, Sendable {
    case goal(LearnerGoal)
    case path(LearningPath)
    case coachMode(CoachMode)
    case authenticationProvider(AuthenticationProvider)
    case restoredSession(Bool)
    case locale(CurriculumLocale)
    case catalogVersion(CurriculumVersion)
    case programID(CurriculumStableID)
    case programVersion(CurriculumVersion)
    case moduleID(CurriculumStableID)
    case moduleVersion(CurriculumVersion)
    case lessonID(CurriculumStableID)
    case lessonVersion(CurriculumVersion)
    case rubricID(CurriculumStableID)
    case rubricVersion(CurriculumVersion)
    case curriculumSource(CurriculumAnalyticsSource)
    case durationBucket(CurriculumDurationBucket)

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
        case .locale:
            .locale
        case .catalogVersion:
            .catalogVersion
        case .programID:
            .programID
        case .programVersion:
            .programVersion
        case .moduleID:
            .moduleID
        case .moduleVersion:
            .moduleVersion
        case .lessonID:
            .lessonID
        case .lessonVersion:
            .lessonVersion
        case .rubricID:
            .rubricID
        case .rubricVersion:
            .rubricVersion
        case .curriculumSource:
            .curriculumSource
        case .durationBucket:
            .durationBucket
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
    case programViewed(ProgramViewAnalyticsContext)
    case moduleViewed(ModuleViewAnalyticsContext)
    case lessonViewed(LessonViewAnalyticsContext)

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
        case let .programViewed(context):
            AnalyticsPayload(
                name: .programViewed,
                parameters: [
                    .locale(context.locale),
                    .catalogVersion(context.catalogVersion),
                    .programID(context.programID),
                    .programVersion(context.programVersion),
                    .curriculumSource(context.source),
                ]
            )
        case let .moduleViewed(context):
            AnalyticsPayload(
                name: .moduleViewed,
                parameters: [
                    .locale(context.locale),
                    .catalogVersion(context.catalogVersion),
                    .programID(context.programID),
                    .programVersion(context.programVersion),
                    .moduleID(context.moduleID),
                    .moduleVersion(context.moduleVersion),
                    .curriculumSource(context.source),
                ]
            )
        case let .lessonViewed(context):
            AnalyticsPayload(
                name: .lessonViewed,
                parameters: [
                    .locale(context.locale),
                    .catalogVersion(context.catalogVersion),
                    .programID(context.programID),
                    .programVersion(context.programVersion),
                    .moduleID(context.moduleID),
                    .moduleVersion(context.moduleVersion),
                    .lessonID(context.lessonID),
                    .lessonVersion(context.lessonVersion),
                    .rubricID(context.rubricID),
                    .rubricVersion(context.rubricVersion),
                    .curriculumSource(context.source),
                    .durationBucket(context.durationBucket),
                ]
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

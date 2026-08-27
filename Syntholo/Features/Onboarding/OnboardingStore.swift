import Observation

@MainActor
@Observable
final class OnboardingStore {
    private(set) var step: OnboardingStep
    private(set) var draft: OnboardingDraft
    private(set) var error: OnboardingError?

    @ObservationIgnored
    private let repository: OnboardingDraftRepository

    init(repository: OnboardingDraftRepository) {
        self.repository = repository
        step = .welcome
        draft = OnboardingDraft()
        error = nil
    }

    var canAdvance: Bool {
        switch step {
        case .welcome:
            true
        case .age:
            draft.ageBand != nil
        case .goal:
            draft.goal != nil
        case .experience:
            draft.experience != nil
        case .pathRecommendation:
            draft.path != nil
        case .coach:
            draft.isReadyForAccount
        case .ageRestricted, .account, .savingProfile, .firstLessonHandoff:
            false
        }
    }

    var canGoBack: Bool {
        switch step {
        case .age, .ageRestricted, .goal, .experience, .pathRecommendation, .coach:
            true
        case .welcome, .account, .savingProfile, .firstLessonHandoff:
            false
        }
    }

    var canRetryProfileSave: Bool {
        step == .account && error == .profileSaveFailed && draft.isReadyForAccount
    }

    func restore() async {
        restoreSavedState()
    }

    func advance() {
        let nextStep: OnboardingStep?
        switch step {
        case .welcome:
            nextStep = .age
        case .age where draft.ageBand != nil:
            nextStep = .goal
        case .goal where draft.goal != nil:
            nextStep = .experience
        case .experience:
            guard let goal = draft.goal,
                  let experience = draft.experience,
                  draft.ageBand != nil else {
                return
            }
            draft.path = PathRecommender.recommend(
                goal: goal,
                experience: experience
            )
            nextStep = .pathRecommendation
        case .pathRecommendation where draft.path != nil:
            nextStep = .coach
        case .coach where draft.isReadyForAccount:
            nextStep = .account
        case .ageRestricted, .account, .savingProfile, .firstLessonHandoff,
             .age, .goal, .pathRecommendation, .coach:
            nextStep = nil
        }

        guard let nextStep else {
            return
        }
        step = nextStep
        error = nil
        persist()
    }

    func goBack() {
        let previousStep: OnboardingStep?
        switch step {
        case .age:
            previousStep = .welcome
        case .ageRestricted, .goal:
            previousStep = .age
        case .experience:
            previousStep = .goal
        case .pathRecommendation:
            previousStep = .experience
        case .coach:
            previousStep = .pathRecommendation
        case .welcome, .account, .savingProfile, .firstLessonHandoff:
            previousStep = nil
        }

        guard let previousStep else {
            return
        }
        step = previousStep
        error = nil
        persist()
    }

    func selectAgeBand(_ ageBand: AgeBand) {
        guard step == .age else {
            return
        }
        draft.ageBand = ageBand
        draft.goal = nil
        draft.experience = nil
        draft.path = nil
        error = nil
        persist()
    }

    func rejectUnderThirteen() {
        guard step == .welcome || step == .age else {
            return
        }
        draft = OnboardingDraft()
        step = .ageRestricted
        error = nil
        persist()
    }

    func selectGoal(_ goal: LearnerGoal) {
        guard step == .goal else {
            return
        }
        draft.goal = goal
        draft.experience = nil
        draft.path = nil
        error = nil
        persist()
    }

    func selectExperience(_ experience: ExperienceLevel) {
        guard step == .experience else {
            return
        }
        draft.experience = experience
        draft.path = nil
        error = nil
        persist()
    }

    func selectPath(_ path: LearningPath) {
        guard step == .pathRecommendation else {
            return
        }
        draft.path = path
        error = nil
        persist()
    }

    func selectCoachMode(_ coachMode: CoachMode) {
        guard step == .coach else {
            return
        }
        draft.coachMode = coachMode
        error = nil
        persist()
    }

    func beginProfileSave() {
        guard step == .account, draft.isReadyForAccount else {
            return
        }
        step = .savingProfile
        error = nil
        persist()
    }

    func profileSaveFailed() {
        guard step == .savingProfile else {
            return
        }
        step = .account
        error = .profileSaveFailed
        persist()
    }

    func retryProfileSave() {
        guard canRetryProfileSave else {
            return
        }
        step = .savingProfile
        error = nil
        persist()
    }

    func profileSaveSucceeded() {
        guard step == .savingProfile else {
            return
        }
        step = .firstLessonHandoff
        error = nil
        try? repository.clear()
    }

    func reset() {
        step = .welcome
        draft = OnboardingDraft()
        error = nil
        try? repository.clear()
    }

    private func restoreSavedState() {
        guard let saved = try? repository.load(),
              Self.isValid(saved) else {
            reset()
            return
        }
        step = saved.step
        draft = saved.draft
        error = nil
    }

    private func persist() {
        try? repository.save(step: step, draft: draft)
    }

    private static func isValid(_ state: OnboardingDraftRepository.State) -> Bool {
        let draft = state.draft
        return switch state.step {
        case .welcome, .age:
            true
        case .ageRestricted:
            draft.ageBand == nil
        case .goal:
            draft.ageBand != nil
        case .experience:
            draft.ageBand != nil && draft.goal != nil
        case .pathRecommendation:
            draft.ageBand != nil && draft.goal != nil && draft.experience != nil
        case .coach, .account, .savingProfile, .firstLessonHandoff:
            draft.isReadyForAccount
        }
    }
}

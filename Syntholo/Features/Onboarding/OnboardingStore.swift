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
        step == .welcome
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
        guard step == .welcome else {
            return
        }
        step = .age
        error = nil
        persist()
    }

    func goBack() {
        let previousStep: OnboardingStep?
        switch step {
        case .age:
            previousStep = .welcome
        case .ageRestricted, .goal:
            draft = OnboardingDraft()
            previousStep = .age
        case .experience:
            draft.goal = nil
            draft.experience = nil
            draft.path = nil
            previousStep = .goal
        case .pathRecommendation:
            draft.experience = nil
            draft.path = nil
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
        step = .goal
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
        step = .experience
        error = nil
        persist()
    }

    func selectExperience(_ experience: ExperienceLevel) {
        guard step == .experience else {
            return
        }
        guard let goal = draft.goal, draft.ageBand != nil else {
            return
        }
        draft.experience = experience
        draft.path = PathRecommender.recommend(
            goal: goal,
            experience: experience
        )
        step = .pathRecommendation
        error = nil
        persist()
    }

    func selectPath(_ path: LearningPath) {
        guard step == .pathRecommendation else {
            return
        }
        draft.path = path
        step = .coach
        error = nil
        persist()
    }

    func selectCoachMode(_ coachMode: CoachMode) {
        guard step == .coach, draft.isReadyForAccount else {
            return
        }
        draft.coachMode = coachMode
        step = .account
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
        case .welcome, .age, .ageRestricted:
            draft == OnboardingDraft()
        case .goal:
            draft.ageBand != nil
                && draft.goal == nil
                && draft.experience == nil
                && draft.path == nil
                && draft.coachMode == .supportive
        case .experience:
            draft.ageBand != nil
                && draft.goal != nil
                && draft.experience == nil
                && draft.path == nil
                && draft.coachMode == .supportive
        case .pathRecommendation:
            draft.isReadyForAccount && draft.coachMode == .supportive
        case .coach:
            draft.isReadyForAccount && draft.coachMode == .supportive
        case .account, .savingProfile, .firstLessonHandoff:
            draft.isReadyForAccount
        }
    }
}

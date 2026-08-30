import Observation

enum OnboardingPersistenceFailure: Equatable, Sendable {
    case load
    case save
    case clear
}

@MainActor
@Observable
final class OnboardingStore {
    private(set) var step: OnboardingStep
    private(set) var draft: OnboardingDraft
    private(set) var error: OnboardingError?
    private(set) var persistenceFailure: OnboardingPersistenceFailure?

    @ObservationIgnored
    private let repository: OnboardingDraftRepository
    @ObservationIgnored
    private var pendingPersistenceAction: PendingPersistenceAction?

    init(repository: OnboardingDraftRepository) {
        self.repository = repository
        step = .welcome
        draft = OnboardingDraft()
        error = nil
        persistenceFailure = nil
        pendingPersistenceAction = nil
    }

    var canAdvance: Bool {
        step == .welcome && persistenceFailure != .load
    }

    var canGoBack: Bool {
        switch step {
        case .age, .goal, .experience, .pathRecommendation, .coach:
            true
        case .welcome, .ageRestricted, .account, .savingProfile, .firstLessonHandoff:
            false
        }
    }

    var recommendedPath: LearningPath? {
        guard let goal = draft.goal, let experience = draft.experience else {
            return nil
        }
        return PathRecommender.recommend(goal: goal, experience: experience)
    }

    var canRetryProfileSave: Bool {
        step == .account && error == .profileSaveFailed && draft.isReadyForAccount
    }

    func restore() async {
        restoreSavedState()
    }

    func advance() {
        guard canAdvance else {
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
        case .goal:
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
        case .welcome, .ageRestricted, .account, .savingProfile, .firstLessonHandoff:
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
        clearPersistedDraft()
    }

    func reset() {
        step = .welcome
        draft = OnboardingDraft()
        error = nil
        clearPersistedDraft()
    }

    func retryPersistence() {
        guard let pendingPersistenceAction else {
            return
        }

        switch pendingPersistenceAction {
        case .load:
            restoreSavedState()
        case let .save(state):
            save(state)
        case .clear:
            clearPersistedDraft()
        }
    }

    private func restoreSavedState() {
        do {
            guard let saved = try repository.load() else {
                step = .welcome
                draft = OnboardingDraft()
                error = nil
                clearPersistenceFailure()
                return
            }
            guard Self.isValid(saved) else {
                step = .welcome
                draft = OnboardingDraft()
                error = nil
                clearPersistedDraft()
                return
            }
            step = saved.step
            draft = saved.draft
            error = nil
            clearPersistenceFailure()
        } catch {
            step = .welcome
            draft = OnboardingDraft()
            self.error = nil
            pendingPersistenceAction = .load
            persistenceFailure = .load
        }
    }

    private func persist() {
        save(.init(step: step, draft: draft))
    }

    private func save(_ state: OnboardingDraftRepository.State) {
        do {
            try repository.save(state)
            clearPersistenceFailure()
        } catch {
            pendingPersistenceAction = .save(state)
            persistenceFailure = .save
        }
    }

    private func clearPersistedDraft() {
        do {
            try repository.clear()
            clearPersistenceFailure()
        } catch {
            pendingPersistenceAction = .clear
            persistenceFailure = .clear
        }
    }

    private func clearPersistenceFailure() {
        pendingPersistenceAction = nil
        persistenceFailure = nil
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

private extension OnboardingStore {
    enum PendingPersistenceAction {
        case load
        case save(OnboardingDraftRepository.State)
        case clear
    }
}

import Foundation
import Observation

enum ProfileRecoveryKind: Equatable {
    case checkingProfile
    case profileCheckFailed
    case savingProfile
    case profileSaveFailed
}

@MainActor
@Observable
final class OnboardingCoordinator {
    let session: AppSession
    let onboardingStore: OnboardingStore
    let authClient: any AuthClient
    private(set) var authenticationError: AuthError?
    private(set) var profileRecoveryKind: ProfileRecoveryKind?

    @ObservationIgnored
    private let profileRepository: any ProfileRepository
    @ObservationIgnored
    private let analytics: any AnalyticsClient
    @ObservationIgnored
    private let now: @Sendable () -> Date
    @ObservationIgnored
    private var pendingUser: AuthenticatedUser?
    @ObservationIgnored
    private var isSavingProfile = false
    @ObservationIgnored
    private var restorationTask: Task<Void, Never>?
    @ObservationIgnored
    private var isRetryingOnboardingPersistence = false

    init(
        session: AppSession,
        onboardingStore: OnboardingStore,
        authClient: any AuthClient,
        profileRepository: any ProfileRepository,
        analytics: any AnalyticsClient,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.session = session
        self.onboardingStore = onboardingStore
        self.authClient = authClient
        self.profileRepository = profileRepository
        self.analytics = analytics
        self.now = now
        authenticationError = nil
        profileRecoveryKind = nil
    }

    func restore() async {
        if let restorationTask {
            await restorationTask.value
            return
        }

        guard session.state == .loading else {
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            await performRestore()
        }
        restorationTask = task
        await task.value
    }

    private func performRestore() async {
        await onboardingStore.restore()
        guard onboardingStore.persistenceFailure != .load else {
            return
        }
        await restoreSessionAfterDraftRecovery()
    }

    private func restoreSessionAfterDraftRecovery() async {
        guard let user = await authClient.restoreSession() else {
            session.transition(
                to: onboardingStore.step == .welcome
                    ? .signedOut
                    : .onboarding
            )
            return
        }

        await resolveRestoredProfile(for: user)
    }

    func retryOnboardingPersistence() async {
        guard !isRetryingOnboardingPersistence else {
            return
        }
        isRetryingOnboardingPersistence = true
        defer { isRetryingOnboardingPersistence = false }

        onboardingStore.retryPersistence()
        guard onboardingStore.persistenceFailure == nil,
              session.state == .loading else {
            return
        }
        await restoreSessionAfterDraftRecovery()
    }

    func authenticated(
        _ user: AuthenticatedUser,
        provider: AuthenticationProvider
    ) async {
        guard onboardingStore.step == .account,
              onboardingStore.draft.isReadyForAccount else {
            return
        }

        pendingUser = user
        authenticationError = nil
        analytics.log(.accountCreated(provider))
        await savePendingProfile()
    }

    /// Entry point for a returning learner who signed in with email, rather
    /// than one whose credentials were still on the device. The profile lookup
    /// is the same; only the analytics reporting and the empty-profile
    /// messaging differ.
    func signedInToExistingAccount(_ user: AuthenticatedUser) async {
        authenticationError = nil
        await resolveRestoredProfile(for: user, restoredSession: false)
    }

    /// Signs the learner out from inside the app.
    ///
    /// Local state is cleared only after the backend confirms the sign-out. If
    /// it fails, the session stays signed in and the error is rethrown, rather
    /// than presenting a signed-out app that still holds live credentials.
    func signOut() async throws {
        try await authClient.signOut()
        pendingUser = nil
        profileRecoveryKind = nil
        authenticationError = nil
        onboardingStore.reset()
        session.transition(to: .signedOut)
    }

    /// The address on the current credential, for display on Profile.
    func currentAccountEmail() async -> String? {
        await authClient.restoreSession()?.email
    }

    func startOnboarding() {
        guard onboardingStore.canAdvance else {
            return
        }
        onboardingStore.advance()
        analytics.log(.onboardingStarted)
        session.transition(to: .onboarding)
    }

    func confirmAge(_ ageBand: AgeBand) {
        guard onboardingStore.step == .age else {
            return
        }
        onboardingStore.selectAgeBand(ageBand)
        analytics.log(.ageConfirmed)
    }

    func selectGoal(_ goal: LearnerGoal) {
        guard onboardingStore.step == .goal else {
            return
        }
        onboardingStore.selectGoal(goal)
        analytics.log(.goalSelected(goal))
    }

    func selectExperience(_ experience: ExperienceLevel) {
        guard onboardingStore.step == .experience else {
            return
        }
        onboardingStore.selectExperience(experience)
        if let recommendedPath = onboardingStore.recommendedPath {
            analytics.log(.pathRecommended(recommendedPath))
        }
    }

    func selectPath(_ path: LearningPath) {
        guard onboardingStore.step == .pathRecommendation else {
            return
        }
        onboardingStore.selectPath(path)
        analytics.log(.pathSelected(path))
    }

    func selectCoachMode(_ mode: CoachMode) {
        guard onboardingStore.step == .coach else {
            return
        }
        onboardingStore.selectCoachMode(mode)
        analytics.log(.coachModeSelected(mode))
    }

    func retryProfileSave() async {
        guard case let .accountPendingProfile(userID) = session.state,
              let pendingUser,
              pendingUser.id == userID,
              profileRecoveryKind == .profileSaveFailed,
              onboardingStore.canRetryProfileSave else {
            return
        }

        onboardingStore.retryProfileSave()
        await savePendingProfile()
    }

    func retryProfileRecovery() async {
        guard case let .accountPendingProfile(userID) = session.state,
              let pendingUser,
              pendingUser.id == userID else {
            return
        }

        switch profileRecoveryKind {
        case .profileCheckFailed:
            await resolveRestoredProfile(for: pendingUser)
        case .profileSaveFailed:
            await retryProfileSave()
        case .checkingProfile, .savingProfile, nil:
            return
        }
    }

    func authenticationFailed(_ error: AuthError) {
        authenticationError = error.shouldPresentMessage ? error : nil
    }

    func completeFirstLessonHandoff() {
        guard session.state == .firstLessonHandoff else {
            return
        }
        onboardingStore.retryPersistence()
        session.transition(to: .signedIn)
    }

    private func savePendingProfile() async {
        guard !isSavingProfile,
              let pendingUser,
              onboardingStore.draft.isReadyForAccount else {
            return
        }

        if onboardingStore.step == .account {
            onboardingStore.beginProfileSave()
        }
        guard onboardingStore.step == .savingProfile else {
            return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }
        profileRecoveryKind = .savingProfile
        session.transition(
            to: .accountPendingProfile(userID: pendingUser.id)
        )

        let profile = LearnerProfile.make(
            user: pendingUser,
            draft: onboardingStore.draft,
            now: now()
        )
        do {
            try await profileRepository.save(profile)
            onboardingStore.profileSaveSucceeded()
            analytics.log(.onboardingCompleted)
            profileRecoveryKind = nil
            session.transition(to: .firstLessonHandoff)
        } catch {
            onboardingStore.profileSaveFailed()
            profileRecoveryKind = .profileSaveFailed
        }
    }

    private func resolveRestoredProfile(
        for user: AuthenticatedUser,
        restoredSession: Bool = true
    ) async {
        pendingUser = user
        profileRecoveryKind = .checkingProfile

        do {
            if try await profileRepository.load(userID: user.id) != nil {
                pendingUser = nil
                profileRecoveryKind = nil
                onboardingStore.reset()
                analytics.log(
                    .loginCompleted(restoredSession: restoredSession)
                )
                session.transition(to: .signedIn)
                return
            }
        } catch {
            profileRecoveryKind = .profileCheckFailed
            session.transition(
                to: .accountPendingProfile(userID: user.id)
            )
            return
        }

        guard onboardingStore.draft.isReadyForAccount,
              onboardingStore.step == .account
                || onboardingStore.step == .savingProfile else {
            profileRecoveryKind = nil
            await abandonUnrecoverableProfile(
                explainToLearner: !restoredSession
            )
            return
        }

        await savePendingProfile()
    }

    private func abandonUnrecoverableProfile(
        explainToLearner: Bool = false
    ) async {
        pendingUser = nil
        profileRecoveryKind = nil
        onboardingStore.reset()
        try? await authClient.signOut()
        // A learner who just tapped "Sign in" and landed back on the welcome
        // screen needs to know why. A silently restored session does not.
        authenticationError = explainToLearner ? .profileSetupRequired : nil
        session.transition(to: .signedOut)
    }
}

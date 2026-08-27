import Foundation
import Observation

@MainActor
@Observable
final class OnboardingCoordinator {
    let session: AppSession
    let onboardingStore: OnboardingStore
    let authClient: any AuthClient
    private(set) var authenticationError: AuthError?

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
    }

    func restore() async {
        guard session.state == .loading else {
            return
        }

        await onboardingStore.restore()
        guard let user = await authClient.restoreSession() else {
            session.transition(
                to: onboardingStore.step == .welcome
                    ? .signedOut
                    : .onboarding
            )
            return
        }

        do {
            if try await profileRepository.load(userID: user.id) != nil {
                analytics.log(.loginCompleted(restoredSession: true))
                session.transition(to: .signedIn)
                return
            }
        } catch {
            guard onboardingStore.draft.isReadyForAccount,
                  onboardingStore.step == .account
                    || onboardingStore.step == .savingProfile else {
                await abandonUnrecoverableProfile(user: user)
                return
            }
            pendingUser = user
            await savePendingProfile()
            return
        }

        guard onboardingStore.draft.isReadyForAccount,
              onboardingStore.step == .account
                || onboardingStore.step == .savingProfile else {
            await abandonUnrecoverableProfile(user: user)
            return
        }

        pendingUser = user
        await savePendingProfile()
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

    func startOnboarding() {
        guard onboardingStore.step == .welcome else {
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
              onboardingStore.canRetryProfileSave else {
            return
        }

        onboardingStore.retryProfileSave()
        await savePendingProfile()
    }

    func authenticationFailed(_ error: AuthError) {
        authenticationError = error.shouldPresentMessage ? error : nil
    }

    func completeFirstLessonHandoff() {
        guard session.state == .firstLessonHandoff else {
            return
        }
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
            session.transition(to: .firstLessonHandoff)
        } catch {
            onboardingStore.profileSaveFailed()
        }
    }

    private func abandonUnrecoverableProfile(
        user _: AuthenticatedUser
    ) async {
        pendingUser = nil
        onboardingStore.reset()
        try? await authClient.signOut()
        session.transition(to: .signedOut)
    }
}

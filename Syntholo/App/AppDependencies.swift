import Foundation
import Observation

enum FirstLessonHandoffPresentationState: Equatable {
    case idle
    case loading
    case retry
}

@MainActor
@Observable
final class FirstLessonHandoffCoordinator {
    private(set) var presentationState: FirstLessonHandoffPresentationState

    @ObservationIgnored
    private let router: AppRouter
    @ObservationIgnored
    private let curriculumStore: CurriculumStore
    @ObservationIgnored
    private let session: AppSession
    @ObservationIgnored
    private let onComplete: @MainActor () -> Void

    init(
        router: AppRouter,
        curriculumStore: CurriculumStore,
        session: AppSession,
        onComplete: @escaping @MainActor () -> Void
    ) {
        self.router = router
        self.curriculumStore = curriculumStore
        self.session = session
        self.onComplete = onComplete
        presentationState = .idle
    }

    func previewFirstLesson() {
        guard session.state == .firstLessonHandoff else {
            return
        }

        switch presentationState {
        case .idle:
            presentationState = .loading
            curriculumStore.load()
        case .retry:
            presentationState = .loading
            curriculumStore.retry()
        case .loading:
            return
        }

        curriculumStoreDidChange()
    }

    func curriculumStoreDidChange() {
        guard presentationState == .loading else {
            return
        }
        guard session.state == .firstLessonHandoff else {
            presentationState = .idle
            return
        }

        switch curriculumStore.state {
        case .loading:
            if !curriculumStore.isLoadActive {
                presentationState = .retry
            }

        case let .ready(snapshot, _):
            complete(using: snapshot)

        case .empty, .unavailable:
            presentationState = .retry

        case let .updateRequired(_, fallbackSnapshot):
            guard let fallbackSnapshot else {
                presentationState = .retry
                return
            }
            complete(using: fallbackSnapshot)
        }
    }

    private func complete(using snapshot: CurriculumSnapshot) {
        guard session.state == .firstLessonHandoff,
              let reference = FirstLessonPreviewResolver.reference(
                  in: snapshot
              ) else {
            presentationState = .retry
            return
        }

        curriculumStore.setPinnedCatalogVersionIDs([
            reference.catalogVersionID,
        ])
        router.presentFirstLesson(reference)

        guard session.state == .firstLessonHandoff else {
            presentationState = .idle
            return
        }
        onComplete()
        presentationState = .idle
    }
}

@MainActor
final class AppDependencies {
    let router: AppRouter
    let onboardingCoordinator: OnboardingCoordinator
    let curriculumStore: CurriculumStore
    let firstLessonHandoffCoordinator: FirstLessonHandoffCoordinator

    init(
        router: AppRouter,
        onboardingCoordinator: OnboardingCoordinator,
        curriculumStore: CurriculumStore
    ) {
        self.router = router
        self.onboardingCoordinator = onboardingCoordinator
        self.curriculumStore = curriculumStore
        firstLessonHandoffCoordinator = FirstLessonHandoffCoordinator(
            router: router,
            curriculumStore: curriculumStore,
            session: onboardingCoordinator.session,
            onComplete: {
                onboardingCoordinator.completeFirstLessonHandoff()
            }
        )
    }

    func restore() async {
        guard onboardingCoordinator.session.state == .loading else {
            return
        }
        router.showLearnHome()
        await onboardingCoordinator.restore()
    }

    static func makeLive(
        configuration: FirebaseRuntimeConfiguration,
        isFirebaseConfigured: Bool
    ) -> AppDependencies {
        let router = AppRouter()
        let session = AppSession(
            configurationAvailable: isFirebaseConfigured
        )

        let onboardingCoordinator: OnboardingCoordinator
        let curriculumRepository: any CurriculumRepository
        let analytics: any AnalyticsClient

        if !isFirebaseConfigured {
            analytics = NoOpAnalyticsClient()
            onboardingCoordinator = OnboardingCoordinator(
                session: session,
                onboardingStore: OnboardingStore(repository: .memory()),
                authClient: UnavailableAuthClient(),
                profileRepository: UnavailableProfileRepository(),
                analytics: analytics
            )
            curriculumRepository = UnavailableCurriculumRepository(
                error: .wrongEnvironment
            )
        } else {
            analytics = FirebaseAnalyticsClient()
            onboardingCoordinator = makeLiveCoordinator(
                session: session,
                analytics: analytics
            )
            curriculumRepository = makeLiveCurriculumRepository(
                configuration: configuration
            )
        }

        let curriculumStore = CurriculumStore(
            repository: curriculumRepository,
            locale: launchLocale,
            analytics: analytics
        )
        return AppDependencies(
            router: router,
            onboardingCoordinator: onboardingCoordinator,
            curriculumStore: curriculumStore
        )
    }

    #if DEBUG
    static func makeUITesting(arguments: [String]) -> AppDependencies {
        let router = AppRouter()
        let session = AppSession(configurationAvailable: true)
        let analytics = NoOpAnalyticsClient()
        let onboardingCoordinator = makeUITestCoordinator(
            session: session,
            arguments: arguments,
            analytics: analytics
        )
        let curriculumStore = CurriculumStore(
            repository: DebugCurriculumFixtures.repository(
                arguments: arguments
            ),
            locale: launchLocale,
            analytics: analytics
        )
        return AppDependencies(
            router: router,
            onboardingCoordinator: onboardingCoordinator,
            curriculumStore: curriculumStore
        )
    }
    #endif

    private static let launchLocale: CurriculumLocale = {
        do {
            return try CurriculumLocale("en-US")
        } catch {
            preconditionFailure("The fixed launch locale must remain canonical.")
        }
    }()

    private static func makeLiveCoordinator(
        session: AppSession,
        analytics: any AnalyticsClient
    ) -> OnboardingCoordinator {
        return OnboardingCoordinator(
            session: session,
            onboardingStore: OnboardingStore(repository: .userDefaults()),
            authClient: FirebaseAuthClient(),
            profileRepository: FirestoreProfileRepository(),
            analytics: analytics
        )
    }

    private static func makeLiveCurriculumRepository(
        configuration: FirebaseRuntimeConfiguration
    ) -> any CurriculumRepository {
        let cache = FileCurriculumCache()
        do {
            return try FirestoreCurriculumRepository(
                cache: cache,
                configuration: configuration
            )
        } catch let error as CurriculumRepositoryError {
            return UnavailableCurriculumRepository(error: error)
        } catch {
            return UnavailableCurriculumRepository(error: .backendFailure)
        }
    }

    #if DEBUG
    private static func makeUITestCoordinator(
        session: AppSession,
        arguments: [String],
        analytics: any AnalyticsClient
    ) -> OnboardingCoordinator {
        let user = AuthenticatedUser(
            id: "ui-test-user",
            email: nil,
            displayName: nil
        )
        let completeDraft = OnboardingDraft(
            ageBand: .adult,
            goal: .studySmarter,
            experience: .beginner,
            path: .school,
            coachMode: .supportive
        )
        let isOnboardingReset = arguments.contains("--onboarding-reset")
        let hasDelayedSignedOutSession = arguments.contains(
            "--session-fixture=delayed-signed-out"
        )
        let hasMissingProfileSignOutFailure = arguments.contains(
            "--session-fixture=missing-profile-sign-out-fails-once"
        )
        let hasHeldProfileLoad = arguments.contains(
            "--profile-load-fixture=fail-once-hold-existing"
        )
        let hasProfileLoadFailure = arguments.contains(
            "--profile-load-fixture=fail-once-existing"
        ) || hasHeldProfileLoad
        let onboardingStorageKey = arguments
            .first { $0.hasPrefix("--onboarding-storage-key=") }
            .map { String($0.dropFirst("--onboarding-storage-key=".count)) }
        var onboardingRepository = onboardingStorageKey.map {
            OnboardingDraftRepository.userDefaults(
                .standard,
                key: "com.syntholo.ui-testing.onboarding.\($0)"
            )
        } ?? .memory()
        if isOnboardingReset {
            try? onboardingRepository.clear()
        }
        if arguments.contains("--onboarding-persistence-fixture=fail-first-save") {
            onboardingRepository = onboardingRepository.failingFirstSave()
        }
        if arguments.contains("--onboarding-persistence-fixture=fail-first-load") {
            onboardingRepository = onboardingRepository.failingFirstLoad()
        }
        if hasMissingProfileSignOutFailure {
            try? onboardingRepository.save(
                step: .goal,
                draft: OnboardingDraft(ageBand: .adult)
            )
        }
        let restoredUser = onboardingStorageKey != nil
            || hasDelayedSignedOutSession
            ? nil
            : user
        let loadedProfile = hasMissingProfileSignOutFailure ? nil : restoredUser.map { restoredUser in
            LearnerProfile.make(
                user: restoredUser,
                draft: completeDraft,
                now: Date(timeIntervalSince1970: 1_800_000_000)
            )
        }
        let profileFailures = arguments.contains("--profile-fixture=fail-once")
            ? 1
            : 0
        let shouldCancelAuthentication = arguments.contains(
            "--provider-fixture=cancelled"
        )
        let holdNanoseconds: UInt64 = 120_000_000_000

        if !isOnboardingReset
            && !hasDelayedSignedOutSession
            && !hasProfileLoadFailure
            && !hasHeldProfileLoad
            && !hasMissingProfileSignOutFailure
            && onboardingStorageKey == nil {
            session.transition(to: .signedIn)
        }

        return OnboardingCoordinator(
            session: session,
            onboardingStore: OnboardingStore(repository: onboardingRepository),
            authClient: UITestAuthClient(
                authenticatedUser: user,
                restoredUser: restoredUser,
                shouldCancelAuthentication: shouldCancelAuthentication,
                restoreDelayNanoseconds: hasDelayedSignedOutSession
                    ? 3_000_000_000
                    : 0,
                signOutFailuresRemaining: hasMissingProfileSignOutFailure ? 1 : 0,
                signOutDelayNanoseconds: hasMissingProfileSignOutFailure
                    ? 5_000_000_000
                    : 0
            ),
            profileRepository: UITestProfileRepository(
                loadedProfile: loadedProfile,
                saveFailuresRemaining: profileFailures,
                loadFailuresRemaining: hasProfileLoadFailure ? 1 : 0,
                saveDelayNanoseconds: arguments.contains(
                    "--profile-fixture=hold-save"
                ) ? holdNanoseconds : 0,
                loadDelayNanoseconds: hasHeldProfileLoad
                    ? holdNanoseconds
                    : 0
            ),
            analytics: analytics,
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }
    #endif
}

private struct UnavailableCurriculumRepository: CurriculumRepository {
    let error: CurriculumRepositoryError

    func load(locale _: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent> {
        AsyncStream { continuation in
            continuation.yield(.unavailable(error: error, saved: nil))
            continuation.finish()
        }
    }
}

private struct UnavailableAuthClient: AuthClient {
    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerNotConfigured
    }

    func restoreSession() async -> AuthenticatedUser? { nil }
    func signOut() async throws {}
}

private struct UnavailableProfileRepository: ProfileRepository {
    func save(_: LearnerProfile) async throws {
        throw ProfileRepositoryError.backendFailure
    }

    func load(userID _: String) async throws -> LearnerProfile? { nil }
}

#if DEBUG
private actor UITestAuthClient: AuthClient {
    private let authenticatedUser: AuthenticatedUser
    private var restoredUser: AuthenticatedUser?
    private let shouldCancelAuthentication: Bool
    private let restoreDelayNanoseconds: UInt64
    private var signOutFailuresRemaining: Int
    private let signOutDelayNanoseconds: UInt64

    init(
        authenticatedUser: AuthenticatedUser,
        restoredUser: AuthenticatedUser?,
        shouldCancelAuthentication: Bool,
        restoreDelayNanoseconds: UInt64,
        signOutFailuresRemaining: Int,
        signOutDelayNanoseconds: UInt64
    ) {
        self.authenticatedUser = authenticatedUser
        self.restoredUser = restoredUser
        self.shouldCancelAuthentication = shouldCancelAuthentication
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
        self.signOutFailuresRemaining = signOutFailuresRemaining
        self.signOutDelayNanoseconds = signOutDelayNanoseconds
    }

    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        if shouldCancelAuthentication {
            throw AuthError.cancelled
        }
        return authenticatedUser
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        if shouldCancelAuthentication {
            throw AuthError.cancelled
        }
        return authenticatedUser
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        if shouldCancelAuthentication {
            throw AuthError.cancelled
        }
        return authenticatedUser
    }

    func restoreSession() async -> AuthenticatedUser? {
        if restoreDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
        }
        return restoredUser
    }

    func signOut() async throws {
        if signOutFailuresRemaining > 0 {
            if signOutDelayNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: signOutDelayNanoseconds)
            }
            signOutFailuresRemaining -= 1
            throw AuthError.providerUnavailable
        }
        restoredUser = nil
    }
}

private actor UITestProfileRepository: ProfileRepository {
    private var loadedProfile: LearnerProfile?
    private var saveFailuresRemaining: Int
    private var loadFailuresRemaining: Int
    private let saveDelayNanoseconds: UInt64
    private let loadDelayNanoseconds: UInt64

    init(
        loadedProfile: LearnerProfile?,
        saveFailuresRemaining: Int,
        loadFailuresRemaining: Int,
        saveDelayNanoseconds: UInt64,
        loadDelayNanoseconds: UInt64
    ) {
        self.loadedProfile = loadedProfile
        self.saveFailuresRemaining = saveFailuresRemaining
        self.loadFailuresRemaining = loadFailuresRemaining
        self.saveDelayNanoseconds = saveDelayNanoseconds
        self.loadDelayNanoseconds = loadDelayNanoseconds
    }

    func save(_ profile: LearnerProfile) async throws {
        if saveDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: saveDelayNanoseconds)
        }
        if saveFailuresRemaining > 0 {
            saveFailuresRemaining -= 1
            throw ProfileRepositoryError.backendFailure
        }
        loadedProfile = profile
    }

    func load(userID: String) async throws -> LearnerProfile? {
        if loadFailuresRemaining > 0 {
            loadFailuresRemaining -= 1
            throw ProfileRepositoryError.backendFailure
        }
        if loadDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: loadDelayNanoseconds)
        }
        guard loadedProfile?.userID == userID else {
            return nil
        }
        return loadedProfile
    }
}
#endif

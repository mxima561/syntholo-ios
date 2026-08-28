import Foundation
import SwiftUI

struct RootView: View {
    @Bindable var router: AppRouter
    @State private var coordinator: OnboardingCoordinator

    init(
        router: AppRouter,
        isFirebaseConfigured: Bool,
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) {
        self.router = router
        _coordinator = State(
            initialValue: RootRuntime.makeCoordinator(
                isFirebaseConfigured: isFirebaseConfigured,
                arguments: arguments
            )
        )
    }

    var body: some View {
        Group {
            switch coordinator.session.state {
            case .loading:
                loadingView
            case .signedOut,
                    .onboarding,
                    .accountPendingProfile,
                    .firstLessonHandoff:
                OnboardingRootView(coordinator: coordinator)
            case .signedIn:
                applicationShell
            case .configurationRequired:
                configurationRequiredView
            }
        }
        .tint(SyntholoColor.accent)
        .task {
            await coordinator.restore()
        }
    }

    private var loadingView: some View {
        ProgressView("Loading Syntholo…")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(SyntholoColor.canvas)
            .accessibilityIdentifier("session.loading")
    }

    private var configurationRequiredView: some View {
        ContentUnavailableView(
            "firebase_setup_required_title",
            systemImage: "wrench.and.screwdriver",
            description: Text("firebase_setup_required_message")
        )
    }

    private var applicationShell: some View {
        TabView(
            selection: Binding(
                get: { router.selectedRoute },
                set: { router.select($0) }
            )
        ) {
            LearnHomeView()
                .tabItem { Label("Learn", systemImage: "book.fill") }
                .tag(AppRoute.learn)
            PracticeHomeView()
                .tabItem { Label("Practice", systemImage: "brain.head.profile") }
                .tag(AppRoute.practice)
            SocialHomeView()
                .tabItem { Label("Social", systemImage: "person.2.fill") }
                .tag(AppRoute.social)
            ProfileHomeView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(AppRoute.profile)
        }
    }
}

@MainActor
private enum RootRuntime {
    static func makeCoordinator(
        isFirebaseConfigured: Bool,
        arguments: [String]
    ) -> OnboardingCoordinator {
        let session = AppSession(
            configurationAvailable: isFirebaseConfigured
        )
        guard isFirebaseConfigured else {
            return OnboardingCoordinator(
                session: session,
                onboardingStore: OnboardingStore(repository: .memory()),
                authClient: UnavailableAuthClient(),
                profileRepository: UnavailableProfileRepository(),
                analytics: NoOpAnalyticsClient()
            )
        }

        #if DEBUG
        if arguments.contains("--ui-testing") {
            return makeUITestCoordinator(
                session: session,
                arguments: arguments
            )
        }
        #endif

        return OnboardingCoordinator(
            session: session,
            onboardingStore: OnboardingStore(repository: .userDefaults()),
            authClient: FirebaseAuthClient(),
            profileRepository: FirestoreProfileRepository(),
            analytics: FirebaseAnalyticsClient()
        )
    }

    #if DEBUG
    private static func makeUITestCoordinator(
        session: AppSession,
        arguments: [String]
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
        let hasHeldProfileLoad = arguments.contains(
            "--profile-load-fixture=fail-once-hold-existing"
        )
        let hasProfileLoadFailure = arguments.contains(
            "--profile-load-fixture=fail-once-existing"
        ) || hasHeldProfileLoad
        let onboardingStorageKey = arguments
            .first { $0.hasPrefix("--onboarding-storage-key=") }
            .map { String($0.dropFirst("--onboarding-storage-key=".count)) }
        let onboardingRepository = onboardingStorageKey.map {
            OnboardingDraftRepository.userDefaults(
                .standard,
                key: "com.syntholo.ui-testing.onboarding.\($0)"
            )
        } ?? .memory()
        if isOnboardingReset {
            try? onboardingRepository.clear()
        }
        let restoredUser = onboardingStorageKey != nil
            || hasDelayedSignedOutSession
            ? nil
            : user
        let loadedProfile = restoredUser.map { restoredUser in
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
            "--auth-fixture=cancelled"
        )
        let holdNanoseconds: UInt64 = 120_000_000_000

        if !isOnboardingReset
            && !hasDelayedSignedOutSession
            && !hasProfileLoadFailure
            && !hasHeldProfileLoad
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
            analytics: NoOpAnalyticsClient(),
            now: { Date(timeIntervalSince1970: 1_800_000_000) }
        )
    }
    #endif
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

    init(
        authenticatedUser: AuthenticatedUser,
        restoredUser: AuthenticatedUser?,
        shouldCancelAuthentication: Bool,
        restoreDelayNanoseconds: UInt64
    ) {
        self.authenticatedUser = authenticatedUser
        self.restoredUser = restoredUser
        self.shouldCancelAuthentication = shouldCancelAuthentication
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
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

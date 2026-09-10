import Foundation
import XCTest
@testable import Syntholo

@MainActor
final class OnboardingCoordinatorTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let user = AuthenticatedUser(
        id: "firebase-user-123",
        email: "learner@example.com",
        displayName: "Taylor Learner"
    )
    private let completeDraft = OnboardingDraft(
        ageBand: .adult,
        goal: .studySmarter,
        experience: .intermediate,
        path: .school,
        coachMode: .socratic
    )

    func testConfiguredSessionStartsLoadingSoLearnCannotAppearDuringRestore() {
        let session = AppSession(configurationAvailable: true)

        XCTAssertEqual(session.state, .loading)
    }

    func testUnavailableConfigurationSelectsConfigurationRequired() {
        let session = AppSession(configurationAvailable: false)

        XCTAssertEqual(session.state, .configurationRequired)
    }

    func testSignedOutRestorationRoutesFreshAndSavedDraftsCorrectly() async throws {
        let fresh = makeCoordinator(restoredUser: nil)
        await fresh.coordinator.restore()
        XCTAssertEqual(fresh.session.state, .signedOut)

        let savedRepository = OnboardingDraftRepository.memory()
        try savedRepository.save(
            step: .experience,
            draft: OnboardingDraft(
                ageBand: .teen,
                goal: .createContent
            )
        )
        let resumed = makeCoordinator(
            restoredUser: nil,
            draftRepository: savedRepository
        )

        await resumed.coordinator.restore()

        XCTAssertEqual(resumed.session.state, .onboarding)
        XCTAssertEqual(resumed.store.step, .experience)
    }

    func testProfileFailureKeepsAuthenticatedSessionAndCompleteDraftForRetry() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            saveFailuresRemaining: 1
        )
        let fixture = makeCoordinator(
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )
        await fixture.store.restore()

        await fixture.coordinator.authenticated(
            user,
            provider: .password
        )

        XCTAssertEqual(
            fixture.session.state,
            .accountPendingProfile(userID: user.id)
        )
        XCTAssertEqual(fixture.store.step, .account)
        XCTAssertEqual(fixture.store.error, .profileSaveFailed)
        XCTAssertEqual(fixture.store.draft, completeDraft)
        XCTAssertTrue(fixture.store.canRetryProfileSave)
        XCTAssertEqual(try draftRepository.load()?.draft, completeDraft)

        let snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.attemptedUserIDs, [user.id])
        XCTAssertTrue(snapshot.savedProfiles.isEmpty)
    }

    func testSuccessfulRetryUsesSameUIDWritesOneProfileAndClearsDraftAfterSave() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            saveFailuresRemaining: 1
        )
        let fixture = makeCoordinator(
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )
        await fixture.store.restore()
        await fixture.coordinator.authenticated(user, provider: .apple)

        XCTAssertNotNil(try draftRepository.load())

        await fixture.coordinator.retryProfileSave()

        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertEqual(fixture.store.step, .firstLessonHandoff)
        XCTAssertNil(try draftRepository.load())
        let snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.attemptedUserIDs, [user.id, user.id])
        XCTAssertEqual(Array(snapshot.savedProfiles.keys), [user.id])
        XCTAssertEqual(snapshot.savedProfiles[user.id]?.selectedPath, .school)
        XCTAssertEqual(snapshot.savedProfiles[user.id]?.coachMode, .socratic)
    }

    func testRestoredCompleteProfileBypassesOnboardingAndClearsDraft() async throws {
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let draftRepository = try repositoryAtAccount()
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: CoordinatorProfileRepository(
                loadedProfile: profile
            ),
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: true)]
        )
        XCTAssertNil(try draftRepository.load())
    }

    func testCompletingHandoffRetriesTransientDraftClearFailure() async throws {
        let storage = CoordinatorDraftStorage(clearFailuresRemaining: 1)
        let draftRepository = storage.repository
        try draftRepository.save(step: .account, draft: completeDraft)
        let fixture = makeCoordinator(draftRepository: draftRepository)
        await fixture.store.restore()

        await fixture.coordinator.authenticated(user, provider: .password)

        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertEqual(fixture.store.persistenceFailure, .clear)
        XCTAssertNotNil(try draftRepository.load())

        fixture.coordinator.completeFirstLessonHandoff()

        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertNil(fixture.store.persistenceFailure)
        XCTAssertNil(try draftRepository.load())
    }

    func testConcurrentCompleteProfileRestorationRunsOneFlight() async {
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let authClient = CoordinatorAuthClient(
            restoredUser: user,
            restoreDelayNanoseconds: 50_000_000
        )
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: profile
        )
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: profileRepository
        )

        async let first: Void = fixture.coordinator.restore()
        async let second: Void = fixture.coordinator.restore()
        _ = await (first, second)

        let authSnapshot = await authClient.snapshot()
        let profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertEqual(authSnapshot.restoreCount, 1)
        XCTAssertEqual(profileSnapshot.loadCount, 1)
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: true)]
        )
    }

    func testConcurrentMissingProfileRestorationCannotOverwriteSuccessfulSave() async throws {
        let draftRepository = try repositoryAtAccount()
        let authClient = CoordinatorAuthClient(
            restoredUser: user,
            restoreDelayNanoseconds: 50_000_000
        )
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            loadDelayAfterFirstNanoseconds: 150_000_000
        )
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        async let first: Void = fixture.coordinator.restore()
        async let second: Void = fixture.coordinator.restore()
        _ = await (first, second)

        let authSnapshot = await authClient.snapshot()
        let profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertEqual(authSnapshot.restoreCount, 1)
        XCTAssertEqual(authSnapshot.signOutCount, 0)
        XCTAssertEqual(profileSnapshot.loadCount, 1)
        XCTAssertEqual(profileSnapshot.attemptedUserIDs, [user.id])
        XCTAssertEqual(
            fixture.analytics.events,
            [.onboardingCompleted]
        )
        XCTAssertNil(try draftRepository.load())
    }

    func testRestoredAuthenticatedUserMissingProfileResumesCanonicalDraftSave() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            saveFailuresRemaining: 1
        )
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(
            fixture.session.state,
            .accountPendingProfile(userID: user.id)
        )
        XCTAssertEqual(fixture.store.step, .account)
        XCTAssertEqual(fixture.store.draft, completeDraft)
        let snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.attemptedUserIDs, [user.id])
        XCTAssertEqual(snapshot.attemptedProfiles.first?.goal, .studySmarter)
        XCTAssertEqual(snapshot.attemptedProfiles.first?.experience, .intermediate)
        XCTAssertEqual(snapshot.attemptedProfiles.first?.selectedPath, .school)
    }

    func testDraftLoadFailurePausesAuthenticatedRestoreUntilRetry() async throws {
        let storage = CoordinatorDraftStorage(loadFailuresRemaining: 1)
        let draftRepository = storage.repository
        try draftRepository.save(step: .account, draft: completeDraft)
        let authClient = CoordinatorAuthClient(restoredUser: user)
        let profileRepository = CoordinatorProfileRepository(loadedProfile: nil)
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(fixture.session.state, .loading)
        XCTAssertEqual(fixture.store.persistenceFailure, .load)
        XCTAssertEqual(try draftRepository.load()?.draft, completeDraft)
        var authSnapshot = await authClient.snapshot()
        var profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(authSnapshot.restoreCount, 0)
        XCTAssertEqual(authSnapshot.signOutCount, 0)
        XCTAssertEqual(profileSnapshot.loadCount, 0)
        XCTAssertTrue(profileSnapshot.attemptedProfiles.isEmpty)

        await fixture.coordinator.retryOnboardingPersistence()

        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertNil(fixture.store.persistenceFailure)
        authSnapshot = await authClient.snapshot()
        profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(authSnapshot.restoreCount, 1)
        XCTAssertEqual(authSnapshot.signOutCount, 0)
        XCTAssertEqual(profileSnapshot.loadCount, 1)
        XCTAssertEqual(profileSnapshot.attemptedUserIDs, [user.id])
        XCTAssertNil(try draftRepository.load())
    }

    func testConcurrentDraftLoadRetriesResumeOneSessionRestoration() async throws {
        let storage = CoordinatorDraftStorage(loadFailuresRemaining: 1)
        let draftRepository = storage.repository
        try draftRepository.save(step: .account, draft: completeDraft)
        let authClient = CoordinatorAuthClient(
            restoredUser: user,
            restoreDelayNanoseconds: 50_000_000
        )
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: profile
        )
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )
        await fixture.coordinator.restore()

        async let first: Void = fixture.coordinator.retryOnboardingPersistence()
        async let second: Void = fixture.coordinator.retryOnboardingPersistence()
        _ = await (first, second)

        let authSnapshot = await authClient.snapshot()
        let profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertEqual(authSnapshot.restoreCount, 1)
        XCTAssertEqual(profileSnapshot.loadCount, 1)
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: true)]
        )
        XCTAssertNil(try draftRepository.load())
    }

    func testRestoredAuthenticatedUserMissingProfileAndDraftSignsOutSafely() async {
        let authClient = CoordinatorAuthClient(restoredUser: user)
        let profileRepository = CoordinatorProfileRepository(loadedProfile: nil)
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: profileRepository
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(fixture.session.state, .signedOut)
        XCTAssertEqual(fixture.store.step, .welcome)
        let signOutCount = await authClient.currentSignOutCount()
        let profileSnapshot = await profileRepository.snapshot()
        XCTAssertEqual(signOutCount, 1)
        XCTAssertTrue(profileSnapshot.attemptedProfiles.isEmpty)
    }

    func testRestoredProfileLoadFailureDoesNotSaveOrClearCanonicalDraft() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            loadFails: true
        )
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(
            fixture.session.state,
            .accountPendingProfile(userID: user.id)
        )
        XCTAssertEqual(
            fixture.coordinator.profileRecoveryKind,
            .profileCheckFailed
        )
        XCTAssertEqual(fixture.store.draft, completeDraft)
        XCTAssertFalse(fixture.store.canRetryProfileSave)
        XCTAssertEqual(try draftRepository.load()?.draft, completeDraft)
        let snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.loadCount, 1)
        XCTAssertTrue(snapshot.attemptedProfiles.isEmpty)
    }

    func testProfileCheckRetryFindsExistingProfileAndClearsDraftWithoutSaving() async throws {
        let draftRepository = try repositoryAtAccount()
        let existingProfile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            loadResults: [
                .failure,
                .profile(existingProfile),
            ]
        )
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()
        await fixture.coordinator.retryProfileRecovery()

        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertNil(fixture.coordinator.profileRecoveryKind)
        let snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.loadCount, 2)
        XCTAssertTrue(snapshot.attemptedProfiles.isEmpty)
        XCTAssertNil(try draftRepository.load())
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: true)]
        )
    }

    func testProfileCheckRetrySavesOnlyAfterSuccessfulMissingProfileResult() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            loadResults: [
                .failure,
                .profile(nil),
            ]
        )
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: profileRepository,
            draftRepository: draftRepository
        )

        await fixture.coordinator.restore()

        var snapshot = await profileRepository.snapshot()
        XCTAssertTrue(snapshot.attemptedProfiles.isEmpty)
        XCTAssertEqual(try draftRepository.load()?.draft, completeDraft)

        await fixture.coordinator.retryProfileRecovery()

        XCTAssertEqual(fixture.session.state, .firstLessonHandoff)
        XCTAssertNil(fixture.coordinator.profileRecoveryKind)
        snapshot = await profileRepository.snapshot()
        XCTAssertEqual(snapshot.loadCount, 2)
        XCTAssertEqual(snapshot.attemptedUserIDs, [user.id])
        XCTAssertNil(try draftRepository.load())
        XCTAssertEqual(fixture.analytics.events, [.onboardingCompleted])
    }

    func testCancellationKeepsAccountScreenWithoutAnError() async throws {
        let fixture = makeCoordinator(draftRepository: try repositoryAtAccount())
        await fixture.store.restore()
        fixture.session.transition(to: .onboarding)

        fixture.coordinator.authenticationFailed(.cancelled)

        XCTAssertEqual(fixture.session.state, .onboarding)
        XCTAssertEqual(fixture.store.step, .account)
        XCTAssertNil(fixture.coordinator.authenticationError)
    }

    func testOnboardingSelectionsEmitOnlyTypedPhaseEvents() {
        let fixture = makeCoordinator()

        fixture.coordinator.startOnboarding()
        fixture.coordinator.confirmAge(.adult)
        fixture.coordinator.selectGoal(.studySmarter)
        fixture.coordinator.selectExperience(.beginner)
        fixture.coordinator.selectPath(.school)
        fixture.coordinator.selectCoachMode(.supportive)

        XCTAssertEqual(fixture.session.state, .onboarding)
        XCTAssertEqual(fixture.store.step, .account)
        XCTAssertEqual(
            fixture.analytics.events,
            [
                .onboardingStarted,
                .ageConfirmed,
                .goalSelected(.studySmarter),
                .pathRecommended(.school),
                .pathSelected(.school),
                .coachModeSelected(.supportive),
            ]
        )
    }

    private func repositoryAtAccount() throws -> OnboardingDraftRepository {
        let repository = OnboardingDraftRepository.memory()
        try repository.save(step: .account, draft: completeDraft)
        return repository
    }

    func testReturningEmailSignInWithSavedProfileEntersAppAsFreshLogin() async {
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let fixture = makeCoordinator(
            profileRepository: CoordinatorProfileRepository(
                loadedProfile: profile
            )
        )

        await fixture.coordinator.signedInToExistingAccount(user)

        XCTAssertEqual(fixture.session.state, .signedIn)
        XCTAssertNil(fixture.coordinator.authenticationError)
        // restoredSession is false: the learner typed credentials, they were
        // not revived from the keychain.
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: false)]
        )
    }

    func testReturningEmailSignInWithoutProfileExplainsWhyItReturnedToWelcome() async {
        let authClient = CoordinatorAuthClient(restoredUser: nil)
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: CoordinatorProfileRepository(loadedProfile: nil)
        )

        await fixture.coordinator.signedInToExistingAccount(user)

        XCTAssertEqual(fixture.session.state, .signedOut)
        XCTAssertEqual(fixture.store.step, .welcome)
        XCTAssertEqual(
            fixture.coordinator.authenticationError,
            .profileSetupRequired
        )
        let signOutCount = await authClient.currentSignOutCount()
        XCTAssertEqual(signOutCount, 1)
    }

    func testSilentRestoreWithoutProfileStaysQuietUnlikeExplicitSignIn() async {
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: CoordinatorProfileRepository(loadedProfile: nil)
        )

        await fixture.coordinator.restore()

        XCTAssertEqual(fixture.session.state, .signedOut)
        // No learner action to explain, so no message.
        XCTAssertNil(fixture.coordinator.authenticationError)
    }

    func testSignOutReturnsToWelcomeOnlyAfterTheBackendConfirms() async throws {
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let fixture = makeCoordinator(
            restoredUser: user,
            profileRepository: CoordinatorProfileRepository(
                loadedProfile: profile
            )
        )
        await fixture.coordinator.restore()
        XCTAssertEqual(fixture.session.state, .signedIn)

        try await fixture.coordinator.signOut()

        XCTAssertEqual(fixture.session.state, .signedOut)
        XCTAssertEqual(fixture.store.step, .welcome)
    }

    func testFailedSignOutKeepsTheLearnerSignedInRatherThanFakingIt() async throws {
        let profile = LearnerProfile.make(
            user: user,
            draft: completeDraft,
            now: now
        )
        let authClient = CoordinatorAuthClient(
            restoredUser: user,
            signOutFails: true
        )
        let fixture = makeCoordinator(
            authClient: authClient,
            profileRepository: CoordinatorProfileRepository(
                loadedProfile: profile
            )
        )
        await fixture.coordinator.restore()
        XCTAssertEqual(fixture.session.state, .signedIn)

        do {
            try await fixture.coordinator.signOut()
            XCTFail("Expected sign-out to propagate the backend failure")
        } catch {
            XCTAssertEqual(AuthError.map(error), .networkUnavailable)
        }

        // Credentials are still live, so the app must not present itself as
        // signed out.
        XCTAssertEqual(fixture.session.state, .signedIn)
    }

    private func makeCoordinator(
        restoredUser: AuthenticatedUser? = nil,
        authClient: CoordinatorAuthClient? = nil,
        profileRepository: CoordinatorProfileRepository? = nil,
        draftRepository: OnboardingDraftRepository = .memory()
    ) -> CoordinatorFixture {
        let session = AppSession(configurationAvailable: true)
        let store = OnboardingStore(repository: draftRepository)
        let analytics = RecordingAnalyticsClient()
        let resolvedAuthClient = authClient
            ?? CoordinatorAuthClient(restoredUser: restoredUser)
        let resolvedProfileRepository = profileRepository
            ?? CoordinatorProfileRepository(loadedProfile: nil)
        let fixedNow = now
        let coordinator = OnboardingCoordinator(
            session: session,
            onboardingStore: store,
            authClient: resolvedAuthClient,
            profileRepository: resolvedProfileRepository,
            analytics: analytics,
            now: { fixedNow }
        )
        return CoordinatorFixture(
            coordinator: coordinator,
            session: session,
            store: store,
            analytics: analytics
        )
    }
}

@MainActor
private struct CoordinatorFixture {
    let coordinator: OnboardingCoordinator
    let session: AppSession
    let store: OnboardingStore
    let analytics: RecordingAnalyticsClient
}

private enum CoordinatorTestError: Error {
    case profileSaveFailed
    case draftLoadFailed
    case draftClearFailed
}

private final class CoordinatorDraftStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var data: Data?
    private var loadFailuresRemaining: Int
    private var clearFailuresRemaining: Int

    init(
        loadFailuresRemaining: Int = 0,
        clearFailuresRemaining: Int = 0
    ) {
        self.loadFailuresRemaining = loadFailuresRemaining
        self.clearFailuresRemaining = clearFailuresRemaining
    }

    var repository: OnboardingDraftRepository {
        OnboardingDraftRepository(
            readData: { [self] in
                try lock.withLock {
                    if loadFailuresRemaining > 0 {
                        loadFailuresRemaining -= 1
                        throw CoordinatorTestError.draftLoadFailed
                    }
                    return data
                }
            },
            writeData: { [self] newData in
                try lock.withLock {
                    if newData == nil, clearFailuresRemaining > 0 {
                        clearFailuresRemaining -= 1
                        throw CoordinatorTestError.draftClearFailed
                    }
                    data = newData
                }
            }
        )
    }
}

private enum CoordinatorProfileLoadResult: Sendable {
    case profile(LearnerProfile?)
    case failure
}

private actor CoordinatorAuthClient: AuthClient {
    struct Snapshot: Sendable {
        let restoreCount: Int
        let signOutCount: Int
    }

    let restoredUser: AuthenticatedUser?
    let emailSignInUser: AuthenticatedUser?
    private let signOutFails: Bool
    private let restoreDelayNanoseconds: UInt64
    private(set) var restoreCount = 0
    private(set) var signOutCount = 0
    private(set) var passwordResetCount = 0

    init(
        restoredUser: AuthenticatedUser?,
        emailSignInUser: AuthenticatedUser? = nil,
        signOutFails: Bool = false,
        restoreDelayNanoseconds: UInt64 = 0
    ) {
        self.restoredUser = restoredUser
        self.emailSignInUser = emailSignInUser
        self.signOutFails = signOutFails
        self.restoreDelayNanoseconds = restoreDelayNanoseconds
    }

    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerUnavailable
    }

    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        guard let emailSignInUser else {
            throw AuthError.invalidCredential
        }
        return emailSignInUser
    }

    func sendPasswordReset(email: String) async throws {
        passwordResetCount += 1
    }

    func signInWithApple(
        idToken: String,
        rawNonce: String,
        fullName: PersonNameComponents?
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerUnavailable
    }

    func signInWithGoogle(
        idToken: String,
        accessToken: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerUnavailable
    }

    func restoreSession() async -> AuthenticatedUser? {
        restoreCount += 1
        if restoreDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: restoreDelayNanoseconds)
        }
        return restoredUser
    }

    func signOut() async throws {
        signOutCount += 1
        if signOutFails {
            throw AuthError.networkUnavailable
        }
    }

    func currentSignOutCount() -> Int {
        signOutCount
    }

    func currentPasswordResetCount() -> Int {
        passwordResetCount
    }

    func snapshot() -> Snapshot {
        Snapshot(
            restoreCount: restoreCount,
            signOutCount: signOutCount
        )
    }
}

private actor CoordinatorProfileRepository: ProfileRepository {
    struct Snapshot: Sendable {
        let attemptedProfiles: [LearnerProfile]
        let savedProfiles: [String: LearnerProfile]
        let loadCount: Int

        var attemptedUserIDs: [String] {
            attemptedProfiles.map(\.userID)
        }
    }

    private let loadedProfile: LearnerProfile?
    private let loadFails: Bool
    private let loadDelayAfterFirstNanoseconds: UInt64
    private var loadResults: [CoordinatorProfileLoadResult]
    private var saveFailuresRemaining: Int
    private var loadCount = 0
    private var attemptedProfiles: [LearnerProfile] = []
    private var savedProfiles: [String: LearnerProfile] = [:]

    init(
        loadedProfile: LearnerProfile?,
        saveFailuresRemaining: Int = 0,
        loadFails: Bool = false,
        loadDelayAfterFirstNanoseconds: UInt64 = 0,
        loadResults: [CoordinatorProfileLoadResult] = []
    ) {
        self.loadedProfile = loadedProfile
        self.saveFailuresRemaining = saveFailuresRemaining
        self.loadFails = loadFails
        self.loadDelayAfterFirstNanoseconds = loadDelayAfterFirstNanoseconds
        self.loadResults = loadResults
    }

    func save(_ profile: LearnerProfile) async throws {
        attemptedProfiles.append(profile)
        if saveFailuresRemaining > 0 {
            saveFailuresRemaining -= 1
            throw CoordinatorTestError.profileSaveFailed
        }
        savedProfiles[profile.userID] = profile
    }

    func load(userID: String) async throws -> LearnerProfile? {
        loadCount += 1
        if loadCount > 1, loadDelayAfterFirstNanoseconds > 0 {
            try? await Task.sleep(
                nanoseconds: loadDelayAfterFirstNanoseconds
            )
        }
        if !loadResults.isEmpty {
            switch loadResults.removeFirst() {
            case let .profile(profile):
                return profile
            case .failure:
                throw CoordinatorTestError.profileSaveFailed
            }
        }
        if loadFails {
            throw CoordinatorTestError.profileSaveFailed
        }
        return loadedProfile
    }

    func snapshot() -> Snapshot {
        Snapshot(
            attemptedProfiles: attemptedProfiles,
            savedProfiles: savedProfiles,
            loadCount: loadCount
        )
    }
}

@MainActor
private final class RecordingAnalyticsClient: AnalyticsClient {
    private(set) var events: [AnalyticsEvent] = []

    func log(_ event: AnalyticsEvent) {
        events.append(event)
    }
}

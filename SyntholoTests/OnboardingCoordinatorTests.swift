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

    func testRestoredCompleteProfileBypassesOnboarding() async {
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
        XCTAssertEqual(
            fixture.analytics.events,
            [.loginCompleted(restoredSession: true)]
        )
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

    func testRestoredProfileLoadFailureRetainsCanonicalDraftForRetry() async throws {
        let draftRepository = try repositoryAtAccount()
        let profileRepository = CoordinatorProfileRepository(
            loadedProfile: nil,
            saveFailuresRemaining: 1,
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
        XCTAssertEqual(fixture.store.draft, completeDraft)
        XCTAssertTrue(fixture.store.canRetryProfileSave)
        XCTAssertEqual(try draftRepository.load()?.draft, completeDraft)
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
}

private actor CoordinatorAuthClient: AuthClient {
    let restoredUser: AuthenticatedUser?
    private(set) var signOutCount = 0

    init(restoredUser: AuthenticatedUser?) {
        self.restoredUser = restoredUser
    }

    func createEmailAccount(
        email: String,
        password: String
    ) async throws -> AuthenticatedUser {
        throw AuthError.providerUnavailable
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
        restoredUser
    }

    func signOut() async throws {
        signOutCount += 1
    }

    func currentSignOutCount() -> Int {
        signOutCount
    }
}

private actor CoordinatorProfileRepository: ProfileRepository {
    struct Snapshot: Sendable {
        let attemptedProfiles: [LearnerProfile]
        let savedProfiles: [String: LearnerProfile]

        var attemptedUserIDs: [String] {
            attemptedProfiles.map(\.userID)
        }
    }

    private let loadedProfile: LearnerProfile?
    private let loadFails: Bool
    private var saveFailuresRemaining: Int
    private var attemptedProfiles: [LearnerProfile] = []
    private var savedProfiles: [String: LearnerProfile] = [:]

    init(
        loadedProfile: LearnerProfile?,
        saveFailuresRemaining: Int = 0,
        loadFails: Bool = false
    ) {
        self.loadedProfile = loadedProfile
        self.saveFailuresRemaining = saveFailuresRemaining
        self.loadFails = loadFails
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
        if loadFails {
            throw CoordinatorTestError.profileSaveFailed
        }
        return loadedProfile
    }

    func snapshot() -> Snapshot {
        Snapshot(
            attemptedProfiles: attemptedProfiles,
            savedProfiles: savedProfiles
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

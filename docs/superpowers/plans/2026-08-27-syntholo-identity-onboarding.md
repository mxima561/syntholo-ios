# Syntholo Identity and Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the complete 13+ onboarding and identity slice so a learner can choose a goal, experience level, specialization, and coach mode, authenticate with Apple, Google, or email/password, persist a privacy-correct profile, and reach Learn with a resumable first-lesson handoff.

**Architecture:** A deterministic onboarding domain model and coordinator sit behind SwiftUI screens and protocol-based auth/profile/analytics clients. Production adapters use Firebase Auth, Firestore, and Analytics; UI and unit tests inject local actors so CI needs no credentials. A checked-in non-secret emulator configuration proves persistence contracts, while environment-specific production Firebase plist files remain outside Git.

**Tech Stack:** Swift 6, SwiftUI, Observation, AuthenticationServices, CryptoKit, Firebase Apple SDK 12.14.0, GoogleSignIn-iOS 9.2.0, Firestore/Auth emulators, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md` — LAW-3, LAW-5–7, LAW-11–12, LAW-15–20; DEC-1–7, DEC-13–22; SHIP-AGE, SHIP-TEEN, SHIP-AUTH, SHIP-ONBOARD, SHIP-FIRST-LESSON, SHIP-ANALYTICS.

## Global Constraints

- Minimum iOS is 17.0; iPhone only; bundle ID remains `com.syntholo.ios`.
- No account creation occurs until the learner explicitly selects `13–17` or `18+`; choosing under 13 stops the flow without collecting a birth date.
- Learners aged 13–17 default to undiscoverable profiles and have no public-ranking surface.
- Auth providers are Apple, Google, and email/password. Apple remains visible whenever Google is visible.
- Five coach modes are Supportive, Funny, Strict, Chill, and Socratic; Supportive is the default. Tone never changes grading.
- The four selectable specializations are School, Work, Creation, and Build. Every learner starts with shared AI Foundations; specialization selection never bypasses Foundations.
- Learner-facing strings live in `Localizable.xcstrings`; no email, age band, answers, prompts, or private profile fields enter analytics.
- Firebase credentials and `GoogleService-Info.plist` never enter Git. Tests use fake clients or Firebase emulators with non-secret local values.
- Expected auth/network/profile failures preserve the onboarding draft and expose retry; cancellation is not presented as an error.
- New behavior follows failing-test → minimal implementation → passing-test. Every task keeps both CI destinations green.

---

### Task 1: Adopt the Binding Product Contract

**Files:**
- Create: `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`
- Create: `docs/superpowers/plans/2026-08-27-syntholo-identity-onboarding.md`
- Modify: `docs/superpowers/specs/2026-08-25-syntholo-ios-mvp-prd.md`
- Modify: `docs/superpowers/plans/2026-08-25-syntholo-ios-release-roadmap.md`
- Modify: `docs/superpowers/plans/2026-08-25-syntholo-ios-foundation.md`

**Interfaces:**
- Consumes: founder-approved Product Bible from the main workspace.
- Produces: one committed binding spec cited by every later slice.

- [ ] **Step 1: Verify the imported contract is internally linked**

Run:

```bash
rg -n 'Status: Binding|SHIP-AGE|SHIP-AUTH|SHIP-ONBOARD|LAW-15|DEC-13' docs/superpowers/specs/2026-08-25-syntholo-product-bible.md
rg -n 'syntholo-product-bible.md' docs/superpowers/plans docs/superpowers/specs/2026-08-25-syntholo-ios-mvp-prd.md
```

Expected: the binding status and every identity requirement appear; foundation, roadmap, historical PRD, and this plan point to the bible.

- [ ] **Step 2: Verify the historical PRD cannot override the bible**

Run:

```bash
sed -n '1,14p' docs/superpowers/specs/2026-08-25-syntholo-ios-mvp-prd.md
```

Expected: status says historical and names the Product Bible as binding.

- [ ] **Step 3: Commit the contract**

```bash
git add docs/superpowers
git commit -m "docs: adopt Syntholo product bible"
```

### Task 2: Add a Credential-Safe Firebase Boundary

**Files:**
- Modify: `project.yml`
- Modify: `.gitignore`
- Modify: `Syntholo/App/SyntholoApp.swift`
- Create: `Syntholo/Infrastructure/Firebase/FirebaseBootstrap.swift`
- Create: `Syntholo/Infrastructure/Firebase/FirebaseRuntimeConfiguration.swift`
- Create: `SyntholoTests/FirebaseRuntimeConfigurationTests.swift`
- Create: `Config/Firebase.example.xcconfig`
- Create: `docs/setup/firebase.md`

**Interfaces:**
- Consumes: `AppEnvironment.current`.
- Produces: `FirebaseRuntimeConfiguration`, `FirebaseBootstrap.configure(_:)`, and injected service construction that never crashes when credentials are absent.

- [ ] **Step 1: Write failing configuration tests**

Add tests proving:

```swift
func testMissingConfigurationKeepsFirebaseUnavailable() {
    let configuration = FirebaseRuntimeConfiguration(
        environment: .development,
        options: nil,
        useEmulators: false
    )
    XCTAssertFalse(configuration.isConfigured)
}

func testEmulatorConfigurationUsesNonSecretProjectIdentity() {
    let configuration = FirebaseRuntimeConfiguration.emulator
    XCTAssertEqual(configuration.projectID, "syntholo-local")
    XCTAssertTrue(configuration.useEmulators)
}
```

- [ ] **Step 2: Run the focused tests and observe RED**

```bash
./scripts/bootstrap.sh
destination="${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo -destination "$destination" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:SyntholoTests/FirebaseRuntimeConfigurationTests
```

Expected: compile failure because `FirebaseRuntimeConfiguration` does not exist.

- [ ] **Step 3: Pin compatible packages and products**

In `project.yml`, add exact package versions. XcodeGen treats the `version` key as an exact requirement:

```yaml
packages:
  Firebase:
    url: https://github.com/firebase/firebase-ios-sdk.git
    version: 12.14.0
  GoogleSignIn:
    url: https://github.com/google/GoogleSignIn-iOS.git
    version: 9.2.0
```

Link `FirebaseCore`, `FirebaseAuth`, `FirebaseFirestore`, `FirebaseAnalytics`, `GoogleSignIn`, and `GoogleSignInSwift` only to the app target. Record why Firebase 12.14.0 is pinned: 12.15.0+ declares Swift tools 6.1, while the iOS 17 CI job intentionally uses Xcode 16.2/Swift 6.0.

- [ ] **Step 4: Implement safe bootstrap behavior**

Use this public shape:

```swift
struct FirebaseRuntimeConfiguration: Sendable, Equatable {
    let environment: AppEnvironment
    let projectID: String?
    let useEmulators: Bool
    let isConfigured: Bool

    static let emulator = FirebaseRuntimeConfiguration(
        environment: .development,
        projectID: "syntholo-local",
        useEmulators: true,
        isConfigured: true
    )
}

@MainActor
enum FirebaseBootstrap {
    static func configure(_ configuration: FirebaseRuntimeConfiguration) -> Bool
}
```

Production configuration loads an ignored environment-specific Firebase plist. Tests and `--ui-testing` use programmatic non-secret emulator options. Missing production configuration returns `false` and lets the root show a setup-safe state instead of calling `fatalError`.

- [ ] **Step 5: Protect credentials and document setup**

Ignore:

```gitignore
GoogleService-Info.plist
Config/Firebase.local.xcconfig
*.firebase.plist
```

Document the Firebase console registration for `com.syntholo.ios`, provider enablement, Apple capability, Google reversed-client URL scheme, and local emulator commands. Example files contain names only, never live identifiers or keys.

- [ ] **Step 6: Run focused tests and commit**

```bash
destination="${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo -destination "$destination" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO -only-testing:SyntholoTests/FirebaseRuntimeConfigurationTests
git add project.yml .gitignore Syntholo Config docs/setup SyntholoTests
git commit -m "build: add safe Firebase runtime boundary"
```

Expected: focused tests pass and the app still launches without credentials.

### Task 3: Define the Onboarding Domain Contract

**Files:**
- Create: `Syntholo/Features/Onboarding/OnboardingModels.swift`
- Create: `Syntholo/Features/Onboarding/PathRecommender.swift`
- Create: `SyntholoTests/OnboardingModelsTests.swift`
- Create: `SyntholoTests/PathRecommenderTests.swift`

**Interfaces:**
- Consumes: Product Bible identity decisions.
- Produces: `AgeBand`, `LearnerGoal`, `ExperienceLevel`, `LearningPath`, `CoachMode`, `OnboardingDraft`, and `PathRecommender.recommend(goal:experience:)`.

- [ ] **Step 1: Write failing model and recommendation tests**

Cover literal raw values and deterministic recommendations:

```swift
func testDefaultDraftUsesSupportiveCoach() {
    XCTAssertEqual(OnboardingDraft().coachMode, .supportive)
}

func testSchoolGoalRecommendsSchoolPath() {
    XCTAssertEqual(
        PathRecommender.recommend(goal: .studySmarter, experience: .beginner),
        .school
    )
}

func testEveryGoalProducesOneSpecialization() {
    for goal in LearnerGoal.allCases {
        XCTAssertNotNil(PathRecommender.recommend(goal: goal, experience: .beginner))
    }
}
```

- [ ] **Step 2: Verify RED**

Run only `OnboardingModelsTests` and `PathRecommenderTests`; expect missing-type compile failures.

- [ ] **Step 3: Implement frozen enums and draft validation**

Use these cases:

```swift
enum AgeBand: String, Codable, Sendable { case teen = "13-17", adult = "18+" }
enum LearnerGoal: String, CaseIterable, Codable, Sendable {
    case studySmarter, workProductivity, createContent, buildWithAI
}
enum ExperienceLevel: String, CaseIterable, Codable, Sendable {
    case beginner, intermediate, advanced
}
enum LearningPath: String, CaseIterable, Codable, Sendable {
    case school, work, creation, build
}
enum CoachMode: String, CaseIterable, Codable, Sendable {
    case supportive, funny, strict, chill, socratic
}
```

`OnboardingDraft.isReadyForAccount` is true only when age band, goal, experience, and path are present. Foundations is not a selectable specialization; it is the mandatory first program.

- [ ] **Step 4: Run tests and commit**

```bash
git add Syntholo/Features/Onboarding SyntholoTests
git commit -m "feat: define onboarding domain"
```

### Task 4: Build a Resumable Onboarding State Machine

**Files:**
- Create: `Syntholo/Features/Onboarding/OnboardingStep.swift`
- Create: `Syntholo/Features/Onboarding/OnboardingStore.swift`
- Create: `Syntholo/Features/Onboarding/OnboardingDraftRepository.swift`
- Create: `SyntholoTests/OnboardingStoreTests.swift`
- Create: `SyntholoTests/OnboardingDraftRepositoryTests.swift`

**Interfaces:**
- Consumes: `OnboardingDraft`, `PathRecommender`.
- Produces: `@Observable @MainActor final class OnboardingStore`, `OnboardingDraftRepository`, and deterministic forward/back transitions.

- [ ] **Step 1: Write failing state tests**

Prove:

```swift
func testUnderThirteenNeverAdvancesToAccount() {
    let store = OnboardingStore(repository: .memory())
    store.rejectUnderThirteen()
    XCTAssertEqual(store.step, .ageRestricted)
    XCTAssertNil(store.draft.ageBand)
}

func testResumeRestoresDraftAndExactStep() async throws {
    let repository = OnboardingDraftRepository.memory()
    try await repository.save(.fixtureThroughExperience)
    let store = OnboardingStore(repository: repository)
    await store.restore()
    XCTAssertEqual(store.step, .pathRecommendation)
}
```

- [ ] **Step 2: Verify RED**

Run the two focused test classes and confirm missing stores cause failure.

- [ ] **Step 3: Implement steps and durable local repository**

```swift
enum OnboardingStep: String, Codable, Sendable {
    case welcome, age, ageRestricted, goal, experience
    case pathRecommendation, coach, account, savingProfile, firstLessonHandoff
}

@MainActor @Observable
final class OnboardingStore {
    private(set) var step: OnboardingStep
    private(set) var draft: OnboardingDraft
    private(set) var error: OnboardingError?
}
```

Persist a versioned Codable envelope to `UserDefaults` after each selection. Back navigation never crosses from age into welcome after the account operation begins. Profile-save failures retain the draft and show retry.

- [ ] **Step 4: Run focused tests and commit**

```bash
git add Syntholo/Features/Onboarding SyntholoTests
git commit -m "feat: add resumable onboarding state"
```

### Task 5: Implement the Original Onboarding Experience

**Files:**
- Create: `Syntholo/Features/Onboarding/OnboardingRootView.swift`
- Create: `Syntholo/Features/Onboarding/WelcomeView.swift`
- Create: `Syntholo/Features/Onboarding/AgeConfirmationView.swift`
- Create: `Syntholo/Features/Onboarding/ChoiceListView.swift`
- Create: `Syntholo/Features/Onboarding/PathRecommendationView.swift`
- Create: `Syntholo/Features/Onboarding/CoachModeView.swift`
- Create: `Syntholo/Features/Onboarding/AccountCreationView.swift`
- Create: `Syntholo/Features/Onboarding/FirstLessonHandoffView.swift`
- Modify: `Syntholo/Resources/Localizable.xcstrings`
- Create: `SyntholoUITests/OnboardingUITests.swift`

**Interfaces:**
- Consumes: `OnboardingStore` and action closures for provider authentication.
- Produces: accessible screens for every Phase 1 step without catalog, paywall, social, or notification interruption.

- [ ] **Step 1: Add a failing UI smoke path**

Launch with `--ui-testing --onboarding-reset --auth-fixture=success` and assert the exact path:

```swift
app.buttons["Start learning"].tap()
app.buttons["I’m 18 or older"].tap()
app.buttons["Study smarter"].tap()
app.buttons["Beginner-friendly"].tap()
app.buttons["Choose AI for School"].tap()
app.buttons["Supportive"].tap()
XCTAssertTrue(app.buttons["Continue with Apple"].exists)
XCTAssertTrue(app.buttons["Continue with Google"].exists)
XCTAssertTrue(app.buttons["Continue with email"].exists)
```

- [ ] **Step 2: Verify RED**

Run `OnboardingUITests`; expect the first button lookup to fail.

- [ ] **Step 3: Build screens from native components**

Use `NavigationStack`, system typography, `PrimaryButton`, SF Symbols, semantic colors, and limited rounding. Each choice is a real `Button` with a selected trait and a minimum 44-point target. The coach screen describes tone only; it does not promise different accuracy. The age-restricted screen offers only “Close Syntholo” guidance and collects no data.

- [ ] **Step 4: Localize every learner-facing string**

Add English entries to `Localizable.xcstrings`. Run:

```bash
rg -n 'Text\("|Button\("|navigationTitle\("' Syntholo/Features/Onboarding
```

Review every match: the string must exist in the catalog or be a test/preview-only value.

- [ ] **Step 5: Run UI smoke and accessibility audits**

Add onboarding audit tests for contrast, hit regions, descriptions, Dynamic Type, clipped text, and traits at the welcome, age, coach, and account checkpoints. Run the focused UI classes.

- [ ] **Step 6: Commit**

```bash
git add Syntholo/Features/Onboarding Syntholo/Resources/Localizable.xcstrings SyntholoUITests
git commit -m "feat: build onboarding flow"
```

### Task 6: Add Three Authentication Providers

**Files:**
- Create: `Syntholo/Services/Auth/AuthClient.swift`
- Create: `Syntholo/Services/Auth/AuthError.swift`
- Create: `Syntholo/Infrastructure/Firebase/FirebaseAuthClient.swift`
- Create: `Syntholo/Infrastructure/Auth/AppleSignInCoordinator.swift`
- Create: `Syntholo/Infrastructure/Auth/AppleNonce.swift`
- Create: `Syntholo/Infrastructure/Auth/GoogleSignInCoordinator.swift`
- Create: `Syntholo/Features/Onboarding/EmailAuthView.swift`
- Create: `Syntholo/Resources/Syntholo.entitlements`
- Modify: `project.yml`
- Modify: `Syntholo/Resources/Info.plist`
- Create: `SyntholoTests/AppleNonceTests.swift`
- Create: `SyntholoTests/AuthErrorTests.swift`

**Interfaces:**
- Produces:

```swift
struct AuthenticatedUser: Sendable, Equatable {
    let id: String
    let email: String?
    let displayName: String?
}

protocol AuthClient: Sendable {
    func createEmailAccount(email: String, password: String) async throws -> AuthenticatedUser
    func signInWithApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> AuthenticatedUser
    func signInWithGoogle(idToken: String, accessToken: String) async throws -> AuthenticatedUser
    func restoreSession() async -> AuthenticatedUser?
    func signOut() async throws
}
```

- [ ] **Step 1: Write failing nonce, validation, cancellation, and error-mapping tests**

Assert 32-character nonces use the documented character set, SHA-256 output is 64 lowercase hexadecimal characters, passwords require at least 8 characters, invalid email is rejected before Firebase, and Apple/Google cancellation maps to `.cancelled` rather than a failure banner.

- [ ] **Step 2: Verify RED**

Run `AppleNonceTests` and `AuthErrorTests`; expect missing types.

- [ ] **Step 3: Implement provider adapters**

Apple uses `SignInWithAppleButton`, a cryptographically secure raw nonce, SHA-256 request nonce, and `OAuthProvider.appleCredential(withIDToken:rawNonce:fullName:)`. Preserve Apple’s name on first sign-in. Google uses the configured `GIDClientID`, obtains ID/access tokens, then creates the Firebase Google credential. Email uses async wrappers over Firebase Auth.

- [ ] **Step 4: Configure capabilities without secrets**

Add the Sign in with Apple entitlement and URL handling seam. The Google reversed client scheme is supplied through ignored local configuration; when absent, the Google button remains visible but presents a setup-safe development message rather than crashing. Production verification rejects missing configuration.

- [ ] **Step 5: Run focused tests and commit**

```bash
git add Syntholo/Services/Auth Syntholo/Infrastructure/Auth Syntholo/Infrastructure/Firebase Syntholo/Features/Onboarding Syntholo/Resources project.yml SyntholoTests
git commit -m "feat: add Firebase authentication providers"
```

### Task 7: Persist a Privacy-Correct Learner Profile

**Files:**
- Create: `Syntholo/Services/Profile/LearnerProfile.swift`
- Create: `Syntholo/Services/Profile/ProfileRepository.swift`
- Create: `Syntholo/Infrastructure/Firebase/FirestoreProfileRepository.swift`
- Create: `SyntholoTests/LearnerProfileTests.swift`
- Create: `SyntholoTests/ProfileRepositoryContractTests.swift`
- Create: `firebase.json`
- Create: `.firebaserc.example`
- Create: `firestore.rules`
- Create: `firestore.indexes.json`
- Create: `tests/firebase/firestore.rules.test.mjs`
- Create: `package.json`

**Interfaces:**
- Consumes: `AuthenticatedUser`, `OnboardingDraft`.
- Produces: `LearnerProfile.make(user:draft:now:)` and `ProfileRepository.save/load`.

- [ ] **Step 1: Write failing privacy-default and repository-contract tests**

```swift
func testTeenProfileIsUndiscoverableByDefault() {
    let profile = LearnerProfile.make(user: .fixture, draft: .teenFixture, now: .fixture)
    XCTAssertFalse(profile.isDiscoverable)
}

func testAdultProfileStillRequiresExplicitDiscoveryConsent() {
    let profile = LearnerProfile.make(user: .fixture, draft: .adultFixture, now: .fixture)
    XCTAssertFalse(profile.isDiscoverable)
}
```

Contract tests require stable `userID`, schema version `1`, mandatory Foundations enrollment, selected specialization, coach mode, experience, goal, created/updated timestamps, and an idempotent retry that does not duplicate profile records.

- [ ] **Step 2: Verify RED**

Run the focused Swift tests; expect missing profile types.

- [ ] **Step 3: Implement profile documents**

Store private identity fields under `users/{uid}` and preferences under `preferences/{uid}`. Create `publicProfiles/{uid}` only with an opaque handle and `isDiscoverable: false`; never copy email or age band into public data. The private `ageBand` is mandatory on first profile creation and immutable afterward so discoverability rules have a stable privacy input. Use a Firestore write batch with merge semantics and server timestamps. A retry with the same UID updates the same documents without changing `ageBand`.

- [ ] **Step 4: Add Firestore rules tests**

Rules must prove:

- unauthenticated reads/writes fail;
- a user can read and write only their own `users/{uid}` and `preferences/{uid}` documents;
- a user cannot change `users/{uid}.ageBand` after its first valid write;
- clients cannot set `publicProfiles/{uid}.isDiscoverable` to true for teen profiles;
- clients cannot write XP, streak, subscription, or another user’s profile;
- exact-match public handle lookup returns only allowed fields.

Run with Firebase Emulator Suite and Node’s built-in test runner:

```bash
npm test
```

- [ ] **Step 5: Run Swift profile tests and commit**

```bash
git add Syntholo/Services/Profile Syntholo/Infrastructure/Firebase SyntholoTests firebase.json .firebaserc.example firestore.rules firestore.indexes.json tests/firebase package.json
git commit -m "feat: persist privacy-safe learner profiles"
```

### Task 8: Complete Account Creation Reliably

**Files:**
- Create: `Syntholo/Features/Onboarding/OnboardingCoordinator.swift`
- Create: `Syntholo/App/AppSession.swift`
- Modify: `Syntholo/App/RootView.swift`
- Modify: `Syntholo/App/SyntholoApp.swift`
- Create: `Syntholo/Services/Analytics/AnalyticsClient.swift`
- Create: `Syntholo/Infrastructure/Firebase/FirebaseAnalyticsClient.swift`
- Create: `SyntholoTests/OnboardingCoordinatorTests.swift`
- Create: `SyntholoTests/AnalyticsEventTests.swift`

**Interfaces:**
- Consumes: `AuthClient`, `ProfileRepository`, `OnboardingStore`.
- Produces: `AppSession`, account/profile recovery states, and privacy-safe onboarding events.

- [ ] **Step 1: Write failing orchestration tests**

Cover:

```swift
func testProfileFailureKeepsAuthenticatedSessionAndDraftForRetry() async {
    // Auth succeeds, profile save fails.
    // Expect accountPendingProfile, unchanged draft, and retry action.
}

func testSuccessfulRetryClearsDraftAndShowsFirstLessonHandoff() async {
    // Retry saves exactly one profile.
    // Expect firstLessonHandoff and cleared local draft.
}
```

Also prove restored authenticated users with complete profiles bypass onboarding, while authenticated users missing profiles resume at `savingProfile`.

- [ ] **Step 2: Verify RED**

Run `OnboardingCoordinatorTests`; expect the coordinator to be missing.

- [ ] **Step 3: Implement session and retry semantics**

```swift
enum AppSessionState: Equatable {
    case loading
    case signedOut
    case onboarding
    case accountPendingProfile(userID: String)
    case firstLessonHandoff
    case signedIn
    case configurationRequired
}
```

Never delete an account merely because profile persistence failed. Retry uses the existing authenticated UID. Clear the local draft only after profile save succeeds. Root routing must not flash Learn while session restoration is loading.

- [ ] **Step 4: Add typed, privacy-safe analytics**

Events for this phase: onboarding started/completed, age confirmed, goal selected, path recommended/selected, coach mode selected, account created, login completed. Event payload types permit only enumerated non-sensitive values and booleans; no free-form string dictionary is exposed to feature code. Tests scan encoded event parameters and reject keys named `email`, `displayName`, `birthDate`, `prompt`, or `answer`.

- [ ] **Step 5: Run focused tests and commit**

```bash
git add Syntholo/App Syntholo/Features/Onboarding Syntholo/Services/Analytics Syntholo/Infrastructure/Firebase SyntholoTests
git commit -m "feat: complete onboarding account orchestration"
```

### Task 9: Prove the Complete Phase 1 Flow

**Files:**
- Modify: `SyntholoUITests/OnboardingUITests.swift`
- Modify: `SyntholoUITests/AppShellUITests.swift`
- Modify: `scripts/test.sh`
- Create: `scripts/test_firebase_rules.sh`
- Create: `docs/quality/identity-onboarding-verification.md`
- Modify: `.github/workflows/ios.yml`

**Interfaces:**
- Consumes: all Phase 1 behavior.
- Produces: canonical local/CI evidence and a stable seam for Phase 2’s first published lesson.

- [ ] **Step 1: Add end-to-end UI tests**

The deterministic UI-test runtime must prove:

- under-13 selection never reaches account creation;
- teen and adult happy paths reach first-lesson handoff;
- all three provider buttons remain available;
- auth cancellation preserves the account screen without an error banner;
- profile-save failure shows Retry and succeeds without repeating auth;
- kill/relaunch resumes the saved onboarding step;
- a completed profile restores directly to Learn;
- no paywall, social prompt, catalog browser, or notification permission appears before handoff.

- [ ] **Step 2: Add accessibility coverage**

Run XCTest audits for contrast, hit regions, descriptions, Dynamic Type, clipped text, and traits at every distinct onboarding layout. Manually verify VoiceOver order and Reduce Motion on the final simulator build; document device/runtime and exact results.

- [ ] **Step 3: Make rules and privacy checks canonical**

`scripts/test_firebase_rules.sh` starts the Firestore emulator on a non-default test port, runs the rules tests, then terminates the emulator. `scripts/test.sh` runs configuration tests, Swift tests, UI tests, onboarding accessibility audits, and the Firebase rules script. CI installs the pinned Firebase CLI and Node dependencies before the test step.

- [ ] **Step 4: Run the full gate twice**

```bash
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
```

Expected: both runs pass; generated hashes match; status contains only the intended Task 9 documentation changes.

- [ ] **Step 5: Scan for credentials and privacy leaks**

```bash
rg -n 'AIza|GOCSPX|PRIVATE KEY|client_secret|sk-[A-Za-z0-9]|GoogleService-Info' . --glob '!DerivedData/**' --glob '!Syntholo.xcodeproj/**'
rg -n 'email|displayName|birthDate|prompt|answer' Syntholo/Services/Analytics Syntholo/Infrastructure/Firebase/FirebaseAnalyticsClient.swift
```

Expected: the first scan finds only example filenames/documentation language and no credential-shaped value; the second finds no forbidden analytics parameter.

- [ ] **Step 6: Write verification evidence and commit**

Document exact Xcode/Firebase SDK/Firebase CLI versions, Debug/Release configuration results, unit/UI/a11y/rules counts, known toolchain warnings, missing live-console credentials, and the manual VoiceOver/Reduce Motion result.

```bash
git add SyntholoUITests scripts .github/workflows/ios.yml docs/quality
git commit -m "test: verify identity and onboarding flow"
```

## Phase 1 Exit Gate

- A 13+ learner can finish onboarding with Apple, Google, or email/password.
- Under-13 learners cannot create an account and no birth date is collected.
- Goal, experience, specialization, coach mode, mandatory Foundations enrollment, and privacy defaults persist under one Firebase UID.
- Auth/profile failures retain learner choices and retry without duplicate records.
- A completed profile reaches the first-lesson handoff and then Learn; Phase 2 owns the published lesson behind that seam.
- Both current-iOS and iOS 17.5 CI jobs pass unit, UI, accessibility, configuration, and Firestore Rules gates.
- Live Firebase console credentials remain an external deployment configuration, never a repository secret.

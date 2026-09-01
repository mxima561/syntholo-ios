# Restored Session Sign-Out Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep a restored authenticated learner in an explicit retry state when a missing-profile cleanup sign-out fails, preserving local onboarding choices until sign-out actually succeeds.

**Architecture:** Extend the existing `ProfileRecoveryKind` state machine rather than adding another session layer. `OnboardingCoordinator` owns the async sign-out attempt and changes the session to `.signedOut` only after `AuthClient.signOut()` succeeds; the existing `OnboardingRootView` renders localized progress and retry states. A deterministic DEBUG fixture proves the failure/retry journey without live Firebase credentials.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift concurrency, XCTest/XCUITest, XcodeGen, String Catalogs

**Spec:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md` (`LAW-11`, `LAW-16`, `LAW-18`, `SHIP-AUTH`, `SHIP-A11Y`) and `docs/superpowers/plans/2026-08-27-syntholo-identity-onboarding.md`

## Global Constraints

- Minimum iOS is 17.0; keep the implementation iPhone-only and compatible with the existing SwiftUI/Observation stack.
- Expected authentication failure must not erase learner work (`LAW-11`).
- Add the failing automated test before behavior (`LAW-18`).
- Put every new learner-facing string in `Syntholo/Resources/Localizable.xcstrings` (`LAW-16`).
- Do not add Firebase, provider credentials, analytics payloads, daily-goal values, curriculum content, or staging behavior.
- Keep Apple, Google, and email/password auth contracts unchanged (`SHIP-AUTH`).
- The recovery control must remain usable with VoiceOver, Dynamic Type, non-color status, and a minimum 44-point target (`SHIP-A11Y`, `DEC-21`).
- Do not clear `pendingUser`, the in-memory draft, or the persisted draft before `AuthClient.signOut()` succeeds.
- Do not transition to `.signedOut` while the authenticated session may still exist.

---

### Task 1: Make missing-profile cleanup sign-out recoverable

**Files:**
- Modify: `Syntholo/Features/Onboarding/OnboardingCoordinator.swift:4-9,188-203,278-297`
- Modify: `Syntholo/Features/Onboarding/OnboardingRootView.swift:108-130,215-309`
- Modify: `Syntholo/App/AppDependencies.swift:253-349,400-460`
- Modify: `Syntholo/Resources/Localizable.xcstrings`
- Modify: `SyntholoTests/OnboardingCoordinatorTests.swift:331-347,577-640`
- Modify: `SyntholoUITests/OnboardingUITests.swift`
- Modify: `scripts/test.sh:181-216,313-326`
- Create: `docs/quality/2026-08-30-phase-1-restored-session-sign-out-recovery-checkpoint.md`

**Interfaces:**
- Consumes: `AuthClient.signOut() async throws`, `AppSessionState.accountPendingProfile(userID:)`, `OnboardingStore.reset()`, and the existing `retryProfileRecovery()` action.
- Produces: `ProfileRecoveryKind.signingOut`, `ProfileRecoveryKind.signOutFailed`, retry-safe `OnboardingCoordinator` behavior, DEBUG argument `--session-fixture=missing-profile-sign-out-fails-once`, and accessibility identifiers `onboarding.sign-out-retry` / `onboarding.sign-out-retry-button`.

- [ ] **Step 1: Add the failing coordinator regression test and a throwing auth fake**

Extend `CoordinatorAuthClient` with a default-zero failure counter:

```swift
private var signOutFailuresRemaining: Int

init(
    restoredUser: AuthenticatedUser?,
    restoreDelayNanoseconds: UInt64 = 0,
    signOutFailuresRemaining: Int = 0
) {
    self.restoredUser = restoredUser
    self.restoreDelayNanoseconds = restoreDelayNanoseconds
    self.signOutFailuresRemaining = signOutFailuresRemaining
}

func signOut() async throws {
    signOutCount += 1
    if signOutFailuresRemaining > 0 {
        signOutFailuresRemaining -= 1
        throw AuthError.providerUnavailable
    }
}
```

Add one regression that starts from a partial persisted draft, proves the first failed cleanup keeps the authenticated recovery surface and exact draft, then proves a retry clears it only after sign-out succeeds:

```swift
func testMissingProfileSignOutFailureKeepsDraftUntilRetrySucceeds() async throws {
    let draft = OnboardingDraft(ageBand: .adult)
    let draftRepository = OnboardingDraftRepository.memory()
    try draftRepository.save(step: .goal, draft: draft)
    let authClient = CoordinatorAuthClient(
        restoredUser: user,
        signOutFailuresRemaining: 1
    )
    let fixture = makeCoordinator(
        authClient: authClient,
        profileRepository: CoordinatorProfileRepository(loadedProfile: nil),
        draftRepository: draftRepository
    )

    await fixture.coordinator.restore()

    XCTAssertEqual(
        fixture.session.state,
        .accountPendingProfile(userID: user.id)
    )
    XCTAssertEqual(fixture.coordinator.profileRecoveryKind, .signOutFailed)
    XCTAssertEqual(fixture.store.step, .goal)
    XCTAssertEqual(fixture.store.draft, draft)
    XCTAssertEqual(try draftRepository.load()?.draft, draft)
    let firstSignOutCount = await authClient.currentSignOutCount()
    XCTAssertEqual(firstSignOutCount, 1)

    await fixture.coordinator.retryProfileRecovery()

    XCTAssertEqual(fixture.session.state, .signedOut)
    XCTAssertNil(fixture.coordinator.profileRecoveryKind)
    XCTAssertEqual(fixture.store.step, .welcome)
    XCTAssertEqual(fixture.store.draft, OnboardingDraft())
    XCTAssertNil(try draftRepository.load())
    let finalSignOutCount = await authClient.currentSignOutCount()
    XCTAssertEqual(finalSignOutCount, 2)
}
```

- [ ] **Step 2: Run the focused coordinator test and confirm RED**

Run:

```bash
./scripts/bootstrap.sh
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoTests/OnboardingCoordinatorTests/testMissingProfileSignOutFailureKeepsDraftUntilRetrySucceeds
```

Expected: FAIL because `ProfileRecoveryKind.signOutFailed` does not exist and the current implementation clears the draft and routes `.signedOut` despite the thrown sign-out.

- [ ] **Step 3: Implement the coordinator state machine without swallowing sign-out errors**

Add the closed states:

```swift
enum ProfileRecoveryKind: Equatable {
    case checkingProfile
    case profileCheckFailed
    case savingProfile
    case profileSaveFailed
    case signingOut
    case signOutFailed
}
```

Route only the failure case back into the cleanup operation:

```swift
case .signOutFailed:
    await abandonUnrecoverableProfile(user: pendingUser)
case .checkingProfile, .savingProfile, .signingOut, nil:
    return
```

Keep the user and draft until sign-out succeeds:

```swift
private func abandonUnrecoverableProfile(
    user: AuthenticatedUser
) async {
    guard pendingUser?.id == user.id else {
        return
    }

    profileRecoveryKind = .signingOut
    session.transition(to: .accountPendingProfile(userID: user.id))

    do {
        try await authClient.signOut()
        pendingUser = nil
        profileRecoveryKind = nil
        onboardingStore.reset()
        session.transition(to: .signedOut)
    } catch {
        profileRecoveryKind = .signOutFailed
    }
}
```

In `resolveRestoredProfile`, pass the nonoptional restored user and do not clear recovery state before this operation begins.

- [ ] **Step 4: Add localized progress and retry views**

Map `.signingOut` to a progress view and `.signOutFailed` to a retry view that calls `retryProfileRecovery()`:

```swift
case .signingOut:
    signingOutView
case .signOutFailed:
    SignOutRetryView {
        Task { @MainActor in
            await coordinator.retryProfileRecovery()
        }
    }
```

Use these exact English source strings and identifiers, and add all strings to `Localizable.xcstrings`:

```swift
private var signingOutView: some View {
    OnboardingPage(
        eyebrow: "ACCOUNT RECOVERY",
        progress: 6,
        title: "Signing out safely",
        introduction: "Keeping your saved choices until sign out finishes.",
        accessibilityIdentifier: "onboarding.signing-out"
    ) {
        ProgressView("Signing out…")
            .frame(maxWidth: .infinity, minHeight: 88)
    }
}

private struct SignOutRetryView: View {
    let onRetry: () -> Void

    var body: some View {
        OnboardingPage(
            eyebrow: "ACCOUNT RECOVERY",
            progress: 6,
            title: "We couldn’t finish signing out",
            introduction: "Your account is still signed in on this device. Try again before continuing.",
            accessibilityIdentifier: "onboarding.sign-out-retry"
        ) {
            Label(
                "Your learning choices are still safe on this device.",
                systemImage: "arrow.clockwise.circle"
            )
            .font(.body)
            .foregroundStyle(OnboardingPalette.academicInk)
            .fixedSize(horizontal: false, vertical: true)

            PrimaryButton(title: "Retry sign out", action: onRetry)
                .accessibilityIdentifier("onboarding.sign-out-retry-button")
        }
    }
}
```

- [ ] **Step 5: Run the focused unit suite and confirm GREEN**

Run:

```bash
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoTests/OnboardingCoordinatorTests
```

Expected: every `OnboardingCoordinatorTests` method passes, including the new failed-sign-out retry regression.

- [ ] **Step 6: Add a deterministic UI fixture and RED functional journey**

In `AppDependencies.makeUITestCoordinator`, recognize exactly:

```swift
let hasMissingProfileSignOutFailure = arguments.contains(
    "--session-fixture=missing-profile-sign-out-fails-once"
)
```

For this fixture, retain the restored user, set `loadedProfile` to `nil`, do not pre-transition the session to `.signedIn`, and construct `UITestAuthClient` with `signOutFailuresRemaining: 1`. Extend `UITestAuthClient.signOut()` with the same fail-once behavior as the unit fake before setting `restoredUser = nil`.

Add the functional journey:

```swift
func testMissingProfileSignOutFailureRequiresSuccessfulRetry() throws {
    let app = launchSession(arguments: [
        "--session-fixture=missing-profile-sign-out-fails-once",
    ])
    let retry = app.buttons["onboarding.sign-out-retry-button"]

    XCTAssertTrue(retry.waitForExistence(timeout: 3))
    XCTAssertFalse(app.buttons["Start learning"].exists)
    retry.tap()

    XCTAssertTrue(app.buttons["Start learning"].waitForExistence(timeout: 3))
    XCTAssertFalse(retry.exists)
}
```

Before implementing the fixture behavior, run this method alone and expect failure because the app currently bypasses the retry surface.

- [ ] **Step 7: Add accessibility coverage and update exact gate counts**

Add to `OnboardingAccessibilityAuditUITests`:

```swift
func testSignOutRecoveryLayoutPassesAccessibilityAudits() throws {
    let app = launchSession(arguments: [
        "--session-fixture=missing-profile-sign-out-fails-once",
    ])

    try audit(
        app,
        waitingFor: app.buttons["onboarding.sign-out-retry-button"]
    )
}
```

Update `scripts/test.sh` exact assertions from 232 to 233 unit tests, 28 to 29 functional UI tests, and 11 to 12 onboarding accessibility tests. The resulting canonical total is 490; do not change the 73 curriculum-content, 32 operator-identity, 38 publication/rollback, 28 AppShell accessibility, 14 curriculum accessibility, or 31 Firestore Rules counts.

- [ ] **Step 8: Run focused UI/a11y proof, then the uninterrupted canonical gate**

Run the two new UI methods first:

```bash
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoUITests/OnboardingUITests/testMissingProfileSignOutFailureRequiresSuccessfulRetry \
  -only-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests/testSignOutRecoveryLayoutPassesAccessibilityAudits
```

Then run:

```bash
./scripts/test.sh
```

Expected: 490/490 pass with zero failure, skip, or cancellation. A timeout-only accessibility retry remains permitted by the existing canonical runner but must be reported if used.

- [ ] **Step 9: Record evidence, scan, and commit**

Create `docs/quality/2026-08-30-phase-1-restored-session-sign-out-recovery-checkpoint.md` with the Product Bible trace, RED failure, implementation behavior, exact test totals, simulator/tool versions, retry usage, evidence limits, and confirmation that no provider credential or live-device claim is made.

Run:

```bash
git diff --check
./scripts/scan_secrets.sh --history --worktree
git status --short
```

Commit only the files listed in this task:

```bash
git add Syntholo/Features/Onboarding/OnboardingCoordinator.swift \
  Syntholo/Features/Onboarding/OnboardingRootView.swift \
  Syntholo/App/AppDependencies.swift \
  Syntholo/Resources/Localizable.xcstrings \
  SyntholoTests/OnboardingCoordinatorTests.swift \
  SyntholoUITests/OnboardingUITests.swift \
  scripts/test.sh \
  docs/quality/2026-08-30-phase-1-restored-session-sign-out-recovery-checkpoint.md
git commit -m "fix(onboarding): recover failed missing-profile sign-out"
```

Expected: the commit contains only this recovery slice, the worktree is clean, and the checkpoint states that live-provider and physical-device certification remain open.

# Restored-session sign-out recovery checkpoint

**Date:** 2026-08-31

## Product Bible trace

- **LAW-11:** A missing profile and failed cleanup sign-out retain the learner's
  persisted onboarding draft until cleanup has actually succeeded.
- **LAW-16:** All new learner-facing recovery copy is present in
  `Localizable.xcstrings`.
- **LAW-18:** Coordinator and UI/a11y coverage were added and observed failing
  before the behavior and fixture changes.
- **DEC-21 / SHIP-A11Y:** The recovery loading and retry pages use the existing
  SwiftUI design system, expose non-color status, preserve the primary button's
  48-point target, suppress draft-mutating Back navigation, and pass VoiceOver,
  Dynamic Type, contrast, clipping, trait, description, and hit-region audits.
- **SHIP-AUTH:** The change is limited to restored authenticated users whose
  profile is absent and whose cleanup sign-out fails.

## TDD evidence

The initial coordinator RED command was:

```sh
./scripts/bootstrap.sh
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoTests/OnboardingCoordinatorTests/testMissingProfileSignOutFailureKeepsDraftUntilRetrySucceeds
```

It failed at compile time because `ProfileRecoveryKind` did not yet define
`.signingOut` or `.signOutFailed`.

The initial functional RED command was:

```sh
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoUITests/OnboardingUITests/testMissingProfileSignOutFailureRequiresSuccessfulRetry
```

It failed because the new missing-profile fixture still bypassed the recovery
surface. A later state-proof RED confirmed the fixture did not yet expose the
exact partial draft and pending-account state.

The focused GREEN evidence was:

```sh
xcodebuild test -quiet -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoTests/OnboardingCoordinatorTests

xcodebuild test -quiet -project Syntholo.xcodeproj -scheme Syntholo \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoUITests/OnboardingUITests/testMissingProfileSignOutFailureRequiresSuccessfulRetry \
  -only-testing:SyntholoUITests/OnboardingAccessibilityAuditUITests/testSignOutRecoveryLayoutPassesAccessibilityAudits
```

## Implemented behavior

- Cleanup sign-out enters `.signingOut` while retaining
  `.accountPendingProfile`, the pending user, and the unmodified draft.
- A sign-out error enters `.signOutFailed`; retry retries only the cleanup
  sign-out. Successful cleanup clears the draft and transitions to signed out.
- Recovery screens provide localized loading and retry states. Back navigation
  is unavailable during every profile-recovery state.
- The DEBUG fixture
  `--session-fixture=missing-profile-sign-out-fails-once` seeds the partial
  adult/goal draft, holds the first failing sign-out for five seconds, and
  makes the successful retry immediate. The DEBUG state proof verifies the
  pending-account session and all draft fields in the existing functional and
  onboarding-a11y methods.

## Canonical gate

The final invocation ran uninterrupted (a prior, non-terminal observation was
discarded rather than counted as evidence):

```sh
./scripts/test.sh
```

Result: **490 passed, 0 failed, 0 skipped, 0 cancelled**:

- 73 curriculum-content
- 32 curriculum-operator-identity
- 38 curriculum-publication/rollback
- 233 unit
- 29 functional UI
- 28 AppShell accessibility
- 14 curriculum accessibility
- 12 onboarding accessibility
- 31 Firestore Rules

No accessibility retry was used. The gate used Xcode 26.6 (17F113), an iPhone
17 Pro simulator running iOS 26.5, Node 22.23.2, Java 21, Firebase CLI 15.28.1,
and Gitleaks 8.30.1.

## Evidence limits

This evidence covers the simulator fixtures and emulator-backed checks only.
No live provider was called, no provider credential was used, and no
physical-device certification is claimed.

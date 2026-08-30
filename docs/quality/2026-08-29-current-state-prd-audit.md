# Syntholo iOS current-state and Product Bible audit

**Audit date:** August 29, 2026  
**Authority:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`  
**Method:** Repository-wide static inspection of product code, tests, configuration, Firestore Rules, plans, and verification ledgers. Runtime build, simulator capture, and fresh accessibility execution were attempted but were unavailable on this host because full Xcode, Simulator, XcodeGen, Node, and npm are not installed or active.

## Executive verdict

Syntholo is a well-structured **Phase 0 foundation with most of the Phase 1 identity/onboarding slice implemented**. It is not yet an internal alpha and is not close to App Store 1.0 as defined by Book III.

The strongest work is the age gate, three-provider authentication architecture, persisted onboarding draft, profile persistence/recovery, teen discoverability default, localization catalog, four-tab shell, test architecture, and Firestore profile rules.

The central product loop does not exist yet. The current “Start the first lesson” action opens a placeholder Learn tab rather than a lesson. Curriculum publishing/versioning, the learning engine, AI evaluation, durable attempts, progress/rewards, daily limits, offline behavior, subscriptions, 1.0 social, profile/operations, and App Store hardening are absent.

## Current standing by delivery phase

| Phase | Current status | Evidence | Exit status |
| --- | --- | --- | --- |
| 0 — Foundation | Substantially implemented | Swift 6/XcodeGen contract, iPhone/iOS 17 settings, design tokens, four-tab shell, CI, localization, unit/UI/a11y tests | Historical evidence says green; fresh gate not runnable on this host |
| 1 — Identity/onboarding | Substantially implemented, with deployment and manual checks open | Age gate, goal, experience, editable path, five coach modes, Apple/Google/email architecture, persisted profile and recovery | Code reaches Learn with a persisted profile; live provider smoke tests, physical-device VoiceOver, and fresh CI remain unverified |
| 2 — Curriculum platform | Missing | No program/module/lesson version entities, sync, admin publisher, publish, or rollback implementation | Fails |
| 3 — Learning engine | Missing | No lesson player, objective quiz, interactive type, prompt builder, attempts, limits, queue, or offline cache | Fails |
| 4 — AI coach | Missing | Coach mode preference exists, but no moderation/scoring/tone pipeline, rubric schema, feedback, follow-up, or revision | Fails |
| 5 — Engagement | Missing | Learn is a placeholder; no Today mission, XP, streak, daily challenge, or review | Fails |
| 6 — Subscriptions | Missing | No StoreKit, products, paywall, entitlement verification, transaction listener, or restore | Fails |
| 7 — 1.0 social | Missing | Social is a placeholder; no friends, requests, reactions, report, or block | Fails |
| 8 — Profile/operations | Missing | Profile is a placeholder; no settings, downloads, deletion, export, help, notification controls, or operational telemetry | Fails |
| 9 — App Store hardening | Not started | No selected app icon, privacy manifest, release assets, StoreKit config, or end-to-end release evidence | Fails |

No Product Bible release milestone is currently met. `GATE-ALPHA` requires Phases 0–4 and an onboarding → lesson → coach → sync → offline-recovery loop; only the beginning of that chain exists.

## Binding requirement alignment

### Aligned or well-seamed

- **DEC-1/2/3/17/19/22:** iOS 17, iPhone-only, `com.syntholo.ios`, Swift 6/SwiftUI/Observation, XcodeGen, and complete strict concurrency are configured.
- **DEC-6/7 and LAW-3:** five coach modes are modeled, Supportive is the default, and experience level is separate from coach personality.
- **SHIP-AGE / LAW-15:** under-13 users are terminally blocked before account controls; only age bands are collected, not birth date.
- **SHIP-AUTH:** Apple, Google, and email/password paths are represented, with Sign in with Apple retained alongside Google.
- **SHIP-TEEN:** profiles default to `isDiscoverable = false`; Rules prevent teen profiles from becoming discoverable.
- **LAW-16:** a String Catalog contains the current learner-facing copy.
- **LAW-19:** current analytics use bounded enums and contain no email, display name, answer, prompt, or submission payloads.
- **LAW-12:** the static credential-shape scan found no obvious shipped secret.
- **SHIP-ONBOARD (partial):** goal, experience, editable recommended path, and coach mode persist through interruption. Daily goal and post-lesson notification choice are not implemented yet.

### Critical gaps and misalignment

1. **The first-lesson promise is false in the current UI.** `FirstLessonHandoffView` labels the action “Start the first lesson,” but `completeFirstLessonHandoff()` only sets the session to `.signedIn`. The destination is `LearnHomeView`, whose copy says the next lesson “will appear here.” This violates **SHIP-FIRST-LESSON** and the Book III new-learner flow if exposed as a usable product.
2. **The learning product itself is absent.** There is no curriculum model, immutable lesson version, publisher, lesson renderer, objective scoring, applied check, feedback, revision, result, attempt ID, progress queue, cache, or content mismatch recovery. This leaves **LAW-1/2/4/8/9/10/11** and nearly all curriculum/learning SHIP items unimplemented.
3. **No server-authoritative product mutations exist beyond profile rules.** XP, streaks, mastery, daily allowance, attempts, entitlements, and social actions have no trusted Functions implementation, idempotency layer, or App Check enforcement.
4. **Practice, Social, and Profile are explicit placeholders.** Their required 1.0 flows are not partial implementations.
5. **Monetization is absent.** There is no visible allowance, fourth-start block, StoreKit 2 flow, localized price, trial disclosure, verified entitlement, transaction updates, restore, or manage-subscription path.
6. **Privacy and operations are incomplete.** There is no in-app account deletion, export request, privacy/safety settings, retention policy implementation, support flow, notification settings, privacy manifest, or App Store privacy evidence.
7. **App Store packaging is knowingly incomplete.** `ASSETCATALOG_COMPILER_APPICON_NAME` is empty and the AppIcon set contains no image. The app cannot be submitted in this state.
8. **Fresh quality evidence is unavailable.** The repository contains extensive historical verification ledgers, but this checkout has no `.git` metadata and this host cannot run Xcode/Simulator or Node/Firebase tooling. Those ledgers are useful context, not proof of the current files.

## Product and UX assessment of the implemented slice

### Strengths

- The onboarding sequence is focused and follows the intended order: welcome, age, goal, experience, route, coach, account, handoff.
- Under-13 handling is clear and avoids collecting unnecessary personal data.
- The recommendation is editable, keeping learner control.
- Recovery distinguishes checking, saving, and retry states, which reduces the risk of losing onboarding choices.
- Current controls use native SwiftUI patterns, minimum 44-point targets, Dynamic Type-friendly sizing, semantic colors, and explicit accessibility identifiers/labels.
- Copy consistently frames AI education around judgment, checking, and responsible use, which aligns with LAW-1.

### Risks

- The six-step “Orientation” count is inconsistent with the actual number of user-visible surfaces when path and handoff are counted, which may make progress feel unreliable.
- The welcome copy says “before your first lesson,” then the eventual lesson CTA opens a placeholder. This damages trust at the highest-value moment.
- The whole onboarding is forced to light mode. That may be an intentional visual decision, but it needs visual and accessibility review on physical devices; it cannot currently be treated as verified.
- “Your choices are safe on this device” is stronger than the implementation guarantees if local persistence fails silently; repository save errors are intentionally ignored in several draft operations.
- The app exposes production auth architecture without checked-in deployment configuration. This is correctly documented, but live Apple/Google/email behavior is not verified here.

## Test, security, and engineering assessment

- The source contains 98 unit-test methods and 54 UI-test methods/helpers by static count. The canonical script claims exact gates of 98 unit, 16 functional UI, 28 AppShell accessibility, 10 onboarding accessibility, and 20 Rules tests.
- CI targets current iOS/Xcode 26.6 and iOS 17.5/Xcode 16.2 with pinned Node and Java versions.
- Firestore Rules tightly constrain initial profile creation, age immutability, opaque handle ownership, paired public-directory state, and teen discoverability.
- Current Firestore Rules intentionally deny deletion. That is safe for Phase 1 but cannot satisfy SHIP-DELETE; deletion will need a trusted backend workflow.
- Firebase and Google Sign-In versions are declared directly in XcodeGen, but there is no checked-in `Package.resolved`; reproducibility depends on the declared compatible-version resolution and upstream availability.
- No privacy manifest, StoreKit configuration, production Firebase plist, or release app icon exists.

## Recommended next sequence

1. **Close Phase 1 evidence:** run the canonical gate on a correctly provisioned Mac, run live Apple/Google/email smoke tests against development Firebase, complete physical-device VoiceOver checks on iOS 17 and current iOS, and either hide/rename the first-lesson CTA in non-demo builds or immediately proceed to the real lesson seam.
2. **Author and implement Phase 2 first:** freeze the versioned content schema, choose the one deep specialization, build the constrained publish/rollback path, and render a published fixture. Do not begin AI scoring before immutable lessons/rubrics exist.
3. **Implement Phase 3 around recovery invariants:** stable attempt IDs, start-credit semantics, deterministic objective scoring, durable queue states, cached resume, and interruption tests. This creates the real first-session loop.
4. **Add Phase 4 AI only after the engine is stable:** moderation, immutable rubric lookup, schema-validated scoring, separate tone rendering, recoverable timeout/schema errors, one free revision, and three free follow-ups.
5. **Then complete engagement, subscriptions, bounded social, and operations in Bible order.** Do not build leagues, leaderboards, free-text social, or certificate infrastructure during 1.0.
6. **Treat release assets and privacy work as continuous gates:** select an app icon, add the privacy manifest when SDK/data usage is final enough, document retention, and keep deletion/export designs current before Phase 8.

## Evidence limits

No fresh screenshots are attached because this host has no active full Xcode installation or Simulator. No claim is made about current visual rendering, clipping, contrast, VoiceOver focus, motion behavior, live authentication, build success, or test success. A complete combined UX/accessibility audit requires a provisioned Mac and fresh captures of every important onboarding state.

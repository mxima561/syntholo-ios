# Syntholo Phase 2 Task 9 first-lesson handoff checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 6–7 and Task 9

**Implementation commit:** `085fbfa` (`feat(app): connect first lesson preview handoff`)

**Documentation commit:** `d7031b8` (`docs(curriculum): record Task 9 checkpoint`)

## Result

The Phase 2 Task 9 root-flow slice is implemented. Syntholo now constructs its router, onboarding coordinator, curriculum repository/cache/store, and first-lesson handoff coordinator once at app root; owns typed Learn navigation in `AppRouter`; and opens the exact immutable read-only first-lesson preview in the same session after Apple, Google, or email onboarding succeeds.

The handoff does not enter the signed-in shell until a validated snapshot resolves the exact route. Failure stays on `.firstLessonHandoff` with learner-safe retry, duplicate taps do not start duplicate streams, and a returning signed-in learner is restored to Learn home instead of a stale preview.

This is not Phase 2 completion, launch approval, original curriculum delivery, or completion of the Product Bible's `SHIP-FIRST-LESSON` gate. The destination remains the sanitized read-only Task 8 preview. Task 10 still owns the complete deterministic curriculum-state fixture matrix, catalog-to-preview UI journeys, and explicit catalog and lesson-preview accessibility audits.

## Test-first evidence

The focused RED run failed at compile time because the new root handoff coordinator contract and `AppRouter` Learn-path operations referenced by the tests did not yet exist. That was the intended RED state; no passing implementation was present behind the new assertions.

After implementation, the settled focused suites passed:

| Focused suite | Result |
| --- | ---: |
| `AppRouterTests` | 6 passed, 0 failed, 0 skipped |
| `FirstLessonHandoffCoordinatorTests` | 10 passed, 0 failed, 0 skipped |
| **Focused aggregate** | **16 passed** |

The complete Swift unit target passes 216/216, and `scripts/test.sh` pins the exact unit count to 216.

The focused coverage proves initial and four-tab router state, path preservation across tab selection, exact route replacement, route clearing for returning learners, route-before-session completion ordering, fail-closed resolution, duplicate-tap one-flight behavior, retry, immediate saved-snapshot handoff, compatible update-required fallback, late-event rejection after leaving handoff, and the absence of curriculum/Firestore infrastructure types from onboarding source.

## Root composition and lifecycle delivered

- `SyntholoApp` creates one `AppDependencies` graph from one resolved Firebase runtime configuration and retains it in root state.
- The graph contains one `AppRouter`, one `OnboardingCoordinator` and session, one `CurriculumStore`, and one `FirstLessonHandoffCoordinator`. The production curriculum repository uses the existing app-owned cache and the same validated runtime configuration.
- `CurriculumStore` remains the only owner of the repository stream. The handoff coordinator observes store state and does not open a second repository load path.
- The handoff presentation has three finite states: idle, loading, and retry. Its exact idle action is **Preview the first lesson**; loading is visible and disabled; failure copy is learner-safe and does not expose backend details.
- Duplicate preview taps are ignored while a load is active. Retry starts one replacement attempt. Saved content and a compatible update-required fallback may resolve immediately without waiting for a fresh network event.
- A successful resolution pins the exact catalog version, installs the Learn lesson route, and only then completes onboarding into `.signedIn`. A missing, duplicated, mismatched, or otherwise invalid first-lesson graph fails closed at the handoff.
- Root restore clears the Learn path before session restoration. Returning signed-in learners therefore land on Learn home, while a late curriculum result cannot reopen the handoff after the session has moved on.
- `OnboardingRootView` receives only the finite handoff presentation state and a preview action. Curriculum snapshots, routes, repositories, and Firestore types do not cross into onboarding source.

## Typed navigation and exact identity delivered

- `AppRouter` remains a main-actor observable, module-internal type. `selectedRoute` is `private(set)`; the Learn path is writable only within the app module so `NavigationStack` can bind to it.
- The first-preview route retains locale plus exact catalog, program, module, lesson, and rubric version IDs. It is installed as `.lesson(reference)` after selecting the Learn tab and replaces any stale Learn path.
- The resolver requires the unique published `ai-foundations` catalog entry, its exact available program version, the program's declared first-lesson version, a unique owning module, the exact lesson and rubric, matching locale and ownership, and a valid `LessonPreviewPresentation`.
- `LearnHomeView` binds its typed `NavigationStack` directly to `AppRouter.learnPath`. Destination rendering retrieves the snapshot by the route's exact catalog version and fails closed to route-unavailable UI when retained identity cannot be satisfied.
- Active Learn routes pin their exact catalog versions in the store. Selecting another primary tab preserves the Learn path; restoring a returning learner explicitly clears it.
- The primary tab contract remains Learn, Practice, Social, and Profile. The onboarding handoff does not insert catalog, paywall, notification, or Social screens before preview.

## Same-session functional UI evidence

The three successful provider journeys now continue beyond handoff and assert the real `curriculum.lesson.preview` destination in the same app process:

1. Adult learner with the Apple success fixture.
2. Adult learner with the Google success fixture.
3. Teen learner with email account creation.

Each journey taps **Preview the first lesson**, waits for the preview destination, confirms the Learn tab is present, and confirms that catalog, plans/upgrade, notification, Social-selection, and repeated-handoff interruptions are absent. These UI assertions prove same-process preview presentation with no intervening detour against a deterministic DEBUG contract snapshot. The focused coordinator tests—not the UI identifier—prove exact route identity and route-before-session-completion ordering. These journeys do not claim exact title/objective verification, original lesson content, a production publication, or an accessibility audit of the lesson-preview screen.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Task 9 result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 216 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **447 passed** |

The uninterrupted run used iPhone 17 Pro / iOS 26.5. No failure, skip, cancellation, retry, or diagnostic opt-out was masked.

## Accessibility evidence and exact boundary

Within the canonical AppShell total, all seven Learn audits—contrast, element detection, hit region, sufficient element description, Dynamic Type, text clipping, and traits—passed against the explicit deterministic loading state. The loading repository seam keeps Learn in that state without contacting Firestore; all seven checks still execute, and the other 21 AppShell audits continue to cover Practice, Social, and Profile.

All 11 onboarding accessibility tests pass. They include the first-lesson handoff layout and its **Preview the first lesson** control, but stop before activating that control. They are handoff accessibility evidence only; they are not an accessibility audit of the rendered lesson preview.

A separate diagnostic run exercised the rendered catalog from the deterministic DEBUG snapshot on iOS 26.5. Six of seven audit categories passed: contrast, element detection, hit region, sufficient element description, text clipping, and traits. Xcode's Dynamic Type checker alone reported a failure. Direct visual comparison showed the catalog text scaling, while the audited process showed CoreText font substitution associated with the checker report, making a checker/runtime false positive likely but not proven. This unresolved diagnostic is recorded rather than suppressed or counted as a seventh pass.

Task 10 still owns deterministic fresh, saved, saved-to-fresh, offline/no-cache, incompatible-with/without-fallback, empty, malformed, and retry fixtures; the catalog-to-program-to-module-to-preview journey; and explicit accessibility audits for the catalog and lesson-preview states. The Task 9 canonical Learn result must therefore be described as **7/7 loading-state shell audits**, not as catalog or lesson-preview accessibility completion.

## DEBUG fixture and Release separation

- The Task 9 DEBUG snapshot is synthetic contract data with an explicit never-publish sentinel. It exists only to resolve exact route identity and prove the same-session preview handoff; it is not learner-facing editorial content.
- `--ui-testing` selects the synthetic repository without contacting live Firestore. The additional exact flag `--curriculum-fixture=loading` selects a nonterminal loading stream only for AppShell accessibility audits.
- The fixture declarations are wholly wrapped in `#if DEBUG`, and the app-composition selection branch is also wrapped in `#if DEBUG`. Release excludes those fixture paths; with valid Firebase configuration it constructs the live production repository, and missing or failed configuration falls closed to the learner-safe unavailable repository.
- An isolated Release simulator build succeeds. Direct executable scans find none of the loading launch flag, DEBUG loading-repository type, synthetic never-publish sentinel, or synthetic lesson ID.
- The Release executable's x86_64 and arm64 slices both declare iOS 17.0 as their minimum OS version.

This is strong compile-time and artifact-separation evidence. It is not proof from an App Store-signed physical-device archive or a production Firebase session.

## Swift 6 and minimum-iOS evidence

The settled project builds in Swift 6 language mode with complete strict-concurrency checking. Root dependencies, router, store, and handoff coordination are main-actor isolated; UI-test clients remain actors or `Sendable` repository values; the loading stream cancels when its owning store task is cancelled.

The focused app build and an isolated Release simulator build succeed with deployment target iOS 17.0. The implementation uses APIs available at that floor, including Observation, typed `NavigationStack`, and the iOS 17 `onChange` overloads. No iOS 18 tab API, iOS 26 visual API, UIKit navigation bridge, or Liquid Glass dependency was introduced.

This MacBook has only the iOS 26.5 simulator runtime. The iOS 17 evidence is compile-time and Mach-O minimum-version evidence only; execution on an installed iOS 17 runtime remains required in CI.

## Scans and independent review

The localization catalog remains valid JSON, the implementation diff passed whitespace validation, and the pinned Gitleaks 8.30.1 complete-history and first-party-worktree scans were clean. The standalone Release artifact and extracted strings/resource surface were also inspected for synthetic fixture and UI-test markers; the DEBUG snapshot and loading seam were absent.

Independent contract, architecture, SwiftUI/accessibility, concurrency/lifetime, source-identity, and final-diff reviews examined one-flight behavior, restore ordering, route pinning, exact identity, main-actor isolation, loading-stream cancellation, DEBUG/Release separation, and the accessibility launch seam. The final reviews reported no remaining P0, P1, or P2 Task 9 issue.

## Deliberate non-claims and open work

- `SHIP-FIRST-LESSON` remains incomplete. Task 9 opens a read-only preview; it does not perform the Phase 3 lesson-start mutation, capture an answer, score work, complete a lesson, or write progress.
- No actual lesson-preview accessibility audit is claimed. The 11 onboarding audits stop at the handoff, and the seven canonical Learn audits target the loading state.
- The rendered catalog's six passing diagnostic categories and unresolved, likely Dynamic Type checker false positive do not close Task 10. Deterministic catalog and preview accessibility coverage remains open and must not be skipped or waived.
- The minimal DEBUG snapshot/loading seam is not the complete Task 10 fixture matrix or its full end-to-end curriculum UI suite.
- No deep launch specialization was selected, inferred, or recommended.
- No original learner-facing curriculum was authored. The synthetic snapshot is contract-only and must never be published.
- No staging or production Firebase content was read, authored, published, rolled back, or otherwise mutated as Task 9 evidence.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent; the content-load decision gate remains closed.
- No iOS 17 runtime, physical-device accessibility run, signed archive, live production configuration, or named owner approval is claimed.
- Privacy-safe route analytics remain Task 11. Subscription, paywall, notification, and Social launch behavior remain outside this task.

Task 10 is next: expand the DEBUG-only deterministic repository matrix, prove every curriculum state and the full catalog-to-preview journey, and add explicit catalog and lesson-preview accessibility coverage without contacting live Firestore.

Phase 2 remains in progress, and no Product Bible release gate is satisfied.

# Syntholo Phase 2 Task 8 Learn state and read-only UI checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 6–7 and Task 8

**Implementation commit:** `0d8ab1f` (`feat(curriculum): add read-only Learn experience`)

**Documentation provenance:** introduced in `5b2b522` (`docs(curriculum): record Task 8 checkpoint`); this field is finalized by the immediately following provenance commit

## Result

The Phase 2 Task 8 feature slice is implemented. Syntholo now has a main-actor observable curriculum store, typed exact-version Learn routes, honest loading/saved/fresh/empty/update-required/unavailable presentation, and catalog, program, module, and sanitized read-only lesson-preview screens driven only by validated `CurriculumSnapshot` values.

This is not root-flow completion, Phase 2 completion, launch approval, or a learner-visible curriculum release. The app shell deliberately retains an honest composition-pending state until Task 9 constructs the production dependency graph once, moves Learn path ownership into `AppRouter`, and connects onboarding to the exact same-session preview route. Task 10 still owns deterministic UI repositories, the proof that `--ui-testing` never contacts Firestore, full curriculum-state UI journeys, and curriculum-state accessibility coverage.

## Test-first evidence

The focused RED sequence failed because `CurriculumStore`, its finite state contract, and the presentation projections did not yet exist. After implementation, the settled focused slice passed:

| Focused suite | Result |
| --- | ---: |
| `CurriculumStoreTests` | 19 passed, 0 failed, 0 skipped |
| `CurriculumPresentationTests` | 7 passed, 0 failed, 0 skipped |
| **Focused aggregate** | **26 passed** |

The complete Swift unit target passes 202/202, and `scripts/test.sh` now pins the exact unit count to 202.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Task 8 result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 202 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **433 passed** |

The run used iPhone 17 Pro / iOS 26.5. No failure, skip, cancellation, or retry was masked.

## Observable state and lifecycle delivered

- `CurriculumStoreState` is a finite learner-safe contract: `loading`, `ready(snapshot, freshness:)`, `empty`, `updateRequired(requiredVersion:fallbackSnapshot:)`, and `unavailable(retryable:)`.
- `CurriculumStore` is `@MainActor @Observable`; repository, task, generation, retention, and route-pin machinery are `@ObservationIgnored` implementation details.
- Initial work begins only through `load()`. Duplicate load/retry requests are suppressed, `refresh()` replaces the active generation, and stale or cancelled generations cannot overwrite current state.
- Locale and repository replacement cancel old work, reset retained identity, and start only the requested locale/environment source.
- A remote failure preserves an already displayed or explicitly returned compatible snapshot as saved content. Raw repository errors, SDK details, document paths, digests, and operator data never enter UI state.
- Snapshot retention keeps the latest two catalog versions plus exact catalog versions pinned by active Learn routes, then prunes deterministically after routes are released.

The 19 store tests cover initial idleness, all stream outcomes, saved-to-fresh behavior, update-required fallback variants, learner-safe error collapse, place preservation, retry, refresh generation control, duplicate suppression, locale/repository replacement, deinitialization cancellation, two-version retention, active-route pinning, pruning, and stable exact-route identity.

## Read-only curriculum presentation delivered

- `LearnRoute` and its program/module/lesson references retain locale plus exact catalog, program, module, lesson, and rubric version identity; routes never depend on row positions.
- Catalog, program, and module projections preserve authored reference order and use stable entity/version IDs.
- `comingSoon` is honest: it has no descendant rows or route.
- Every presentation projection validates the exact catalog/program/module/lesson/rubric hierarchy and fails closed when identity, ownership, locale, order, or referenced data does not match.
- The lesson preview exposes title, objective, locale-aware duration, lesson/rubric versions, concept content, the authored diagram plus text alternative, static question options, and criterion title/description.
- Question options are deliberately non-interactive and labeled as a read-only preview. The UI does not expose correct-answer identity, scoring values, deterministic feedback, evaluation-contract identity, digests, Firestore paths, rights workflow data, completion, progress, attempts, AI, or paywall behavior.
- All fixed Task 8 interface copy is present in `Localizable.xcstrings`; runtime curriculum strings remain authored content carried by the validated locale snapshot.

The seven presentation tests prove authored ordering, exact hierarchy, honest `comingSoon`, stable block/option/asset/node/connector identity, diagram text alternatives, fail-closed missing references, and the sanitized lesson-field whitelist.

## SwiftUI and accessibility evidence

The implementation uses iOS 17-compatible native SwiftUI: Observation, typed value navigation, stable `ForEach` identity, native `Button`/`NavigationLink`, semantic text styles and colors, Dynamic Type-aware layout, decorative-image hiding, and localized fixed copy. No iOS 18 tab API, iOS 26 visual API, UIKit bridge, or Liquid Glass dependency was introduced.

The focused app build succeeds, and an isolated Swift 6/iOS 17 deployment-target typecheck succeeds. This is compile-time compatibility evidence only: the iOS 17 simulator runtime is not installed on this MacBook, so the configured minimum-iOS CI job remains required.

The seven existing Learn AppShell accessibility audits pass after two defects were found and repaired:

1. The retry control's 48-point minimum height was moved inside the `Button` label so the interactive hit region—not only its surrounding layout—meets the target.
2. The temporary root composition-pending fallback was replaced with a custom semantic, scrollable status view after native `ContentUnavailableView` defaults narrowly failed contrast and then clipped at an accessibility Dynamic Type size.

These seven audits cover the temporary root fallback exposed before Task 9; they do not replace Task 10's required deterministic audits of every curriculum data/state screen.

## Release simulator and bundle evidence

A standalone Release simulator build succeeds with deployment target iOS 17.0, `SYNTHOLO_ENV = production`, bundle identifier `com.syntholo.ios`, and a universal simulator executable. Direct app-bundle and extracted-strings/normalized-plist scans are clean under the pinned Gitleaks policy. The built app contains no synthetic curriculum fixture, test artifact, or private curriculum-path marker.

Gitleaks 8.30.1 also reports no leak across the complete 21-commit Git history (approximately 2.54 MB examined) or the first-party worktree (approximately 2.48 MB examined).

This is resource-separation and unsigned Release-simulator evidence. It is not an App Store-signed physical-device archive, iOS 17 runtime execution, or live production configuration proof.

## Independent review

Independent store/concurrency, contract/privacy, and accessibility reviews found and drove repairs for stale-generation control, fallback retention, route-snapshot lifetime, presentation sanitization, retry hit-region size, fallback contrast, and Dynamic Type clipping. After the repairs, the reviewers reported no remaining P0, P1, or P2 Task 8 issue.

## Deliberate non-claims and open work

- Production root composition is not connected. `LearnHomeView(store:)` is the implemented Task 8 injection seam; the existing no-argument app-shell entry shows an honest composition-pending state until Task 9 replaces it.
- `AppRouter` does not yet own the Learn path, and onboarding does not yet install the exact lesson route before entering the signed-in shell. Both are Task 9.
- The debug memory repository, `--ui-testing` no-Firestore guarantee, end-to-end curriculum journeys, and accessibility coverage for every data/state screen remain Task 10.
- Privacy-safe curriculum route analytics remain Task 11.
- No answer capture, correct-answer display, scoring, completion, progress, attempt, AI, subscription, or paywall behavior was added.
- No original learner-facing curriculum was authored, no deep launch specialization was selected, inferred, or recommended, and no staging or production Firebase write occurred.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent; the content-load decision gate remains closed.
- Only iOS 26.5 ran locally. Minimum-iOS 17 runtime execution, physical-device accessibility, live Firebase/staging proof, and named owner approvals remain open.
- The uninterrupted 433-test canonical gate, complete-history/worktree scan, and standalone Release simulator app-bundle verification are complete and green as recorded above.

Task 9 is next: build root dependencies once, move typed Learn navigation into `AppRouter`, and connect the onboarding handoff to the exact immutable read-only preview in the same session. `SHIP-FIRST-LESSON` remains incomplete until Phase 3 adds a real lesson-start mutation and interactive learning loop.

Phase 2 remains in progress, and no Product Bible release gate is satisfied.

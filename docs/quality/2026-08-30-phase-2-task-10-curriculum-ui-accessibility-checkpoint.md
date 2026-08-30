# Syntholo Phase 2 Task 10 curriculum UI and accessibility checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 6–7 and Task 10

**Implementation commit:** `b9083a7` (`feat(curriculum): add deterministic UI coverage`)

**Documentation provenance:** this checkpoint records implementation commit `b9083a7`; the documentation commit is identified by Git history

## Result

Phase 2 Task 10 is complete at its synthetic DEBUG fixture, functional UI, formal test-composition, and automated catalog/preview accessibility scope. Syntholo now has deterministic in-memory curriculum modes for fresh, saved-terminal, saved-to-fresh, offline without cache, incompatible content with and without a compatible fallback, empty, a typed malformed terminal event, fail-once/retry recovery, and retained loading.

The functional UI suite verifies each learner-visible state, the catalog → program → module → exact read-only preview journey, and the exact synthetic title/objective after the Apple, Google, and email onboarding journeys. The preview is now an immersive nested destination with the fixed localized **Read-only lesson preview** header and a 48-point Back button. The tab bar is hidden while the preview is open; Back returns to the module and restores the tab shell.

This Task 10 behavior supersedes only Task 9's historical post-preview chrome assertion that the Learn tab was visible while preview content was on screen. It does not change Task 9's exact route identity, route-before-session-completion order, same-session handoff, or no-interruption evidence.

This is not Phase 2 completion, launch approval, original curriculum delivery, or completion of `SHIP-FIRST-LESSON` or `SHIP-A11Y`. Task 11 privacy-safe curriculum analytics is next.

## Focused evidence

The settled focused checks passed:

| Focused evidence | Result |
| --- | ---: |
| DEBUG fixture and launch-composition unit tests | 8 passed, 0 failed, 0 skipped |
| Apple, Google, and email exact-preview journeys | 3 passed, 0 failed, 0 skipped |
| Fresh catalog → preview → Back/tab-restoration journey | 1 passed, 0 failed, 0 skipped |
| Final focused contrast and clipped-text rechecks | 2 passed, 0 failed, 0 skipped |
| Final focused accessibility5 layout recheck | 1 passed, 0 failed, 0 skipped |

The eight focused unit tests cover selector defaulting and exact modes, invalid/duplicate selector rejection, exact terminal event sequences, retained fail-once state across subscriptions, retained loading until cancellation, every curriculum fixture selecting test composition before Firebase, non-exact UI-test tokens selecting live composition, and the defensive Firebase-bootstrap early return.

## Deterministic fixture and UI-state coverage

- `fresh` yields one validated synthetic fresh snapshot and supports the complete stable-ID catalog → program → module → lesson-preview route.
- `saved` yields saved content followed by a terminal refresh failure; the catalog remains usable with non-color saved/error status and retry.
- `saved-to-fresh` keeps the catalog visible while refreshing, then removes saved status after the deterministic fresh transition.
- `offline-no-cache` presents learner-safe unavailable copy and a 48-point retry control without exposing a catalog.
- `incompatible-with-fallback` keeps compatible saved content below an explicit update-required banner; `incompatible-without-fallback` blocks unsafe rendering without offering a meaningless retry.
- `empty` presents the honest no-published-curriculum state without catalog or retry.
- `malformed` is a typed malformed repository terminal event that collapses to the learner-safe unavailable state and does not expose its debug path or error type. It is not evidence that malformed bytes were passed through the decoder.
- `fail-once-retry` retains repository identity across subscriptions so retry recovers to the fresh catalog.
- `loading` remains nonterminal until cancellation and preserves the existing AppShell loading-audit seam.

The synthetic graph retains its explicit never-publish sentinel. It is contract data, not original editorial curriculum and not a candidate for staging or production publication.

## Formal no-Firebase/no-Firestore test-composition proof

An exact `--ui-testing` token selects `AppDependencies.makeUITesting(arguments:)` before Firebase runtime configuration is read, Firebase bootstrap is invoked, or live dependencies are constructed. Injected closure counters prove zero configuration reads, zero bootstrap calls, and zero live-dependency construction for every declared curriculum fixture. Missing or non-exact tokens take the Firebase-backed branch, which proves the selector is fail-closed rather than prefix-based.

`FirebaseBootstrap.configure` also has a DEBUG defense-in-depth guard that returns before `FirebaseApp.app()`, `FirebaseApp.configure`, emulator configuration, or `Firestore.firestore()` is evaluated. The test composition uses memory onboarding/auth/profile clients, no-op analytics, and the DEBUG in-memory curriculum repository.

This makes live Firebase/Firestore construction unreachable through the app's exact `--ui-testing` launch composition. It is source/control-flow proof, not a packet capture, proof that Firebase frameworks are absent from the Debug binary, or evidence from a live production Firebase session.

## Exact preview and immersive navigation evidence

All three successful onboarding providers assert the exact synthetic title **Synthetic contract lesson** and objective **Validate a synthetic placeholder graph without supplying editorial curriculum.** after the same-process handoff. The fresh catalog journey separately selects the exact program, module, and lesson stable IDs before asserting the same title/objective.

The lesson preview uses native SwiftUI controls and a localized fixed header. Its Back button uses the shared 48-point minimum control dimension. Functional evidence proves that Back restores the module destination and visible Learn tab. The immersive destination hides navigation and tab chrome only while preview is active; it does not add a fifth tab or change the four-tab shell.

iOS 26 uses availability-gated `scrollEdgeEffectHidden`; iOS 17 uses the explicit fallback without that modifier. Task 10 therefore maintains the iOS 17 source/deployment floor but does introduce one guarded iOS 26 visual API. No claim that Task 10 uses only iOS 17 APIs is made.

## Automated accessibility evidence and boundary

The canonical gate runs 14 isolated `CurriculumAccessibilityAuditUITests` methods: seven against the fresh catalog and seven against its exact lesson preview. Each screen has dedicated contrast, element-detection, hit-region, sufficient-element-description, clipped-text, and trait methods. A separate accessibility5 method per screen forces SwiftUI's maximum accessibility Dynamic Type size in the DEBUG UI-test composition, verifies measured height growth for the catalog title and for the preview title/objective, and runs clipped-text checks across the covered viewports.

Preview audits address each semantic card individually. A card that fits is positioned near-fully within the derived content viewport before the audit; an oversized card is audited at both its top and bottom. The preview retains all meaningful card content in the accessibility tree. Diagram graphics are decorative to assistive technology while the authored text alternative remains exposed. The fixed Back label is localized and its interactive frame is 48×48 points.

The raw XCTest `.dynamicType` audit category is deliberately not run or counted. The evidence instead consists of an exact accessibility5 environment override, measured growth assertions, and clipped-text audits. The 14-method result applies only to the fresh synthetic catalog and its preview; the other deterministic fixtures have functional state coverage, not separate accessibility-audit methods.

These simulator audits do not prove spoken VoiceOver focus order or announcements, Reduce Motion, Switch Control, physical-device behavior, an installed iOS 17 runtime, captions/transcripts, every Phase 2 screen/state, or `SHIP-A11Y`. Those named physical and full-phase checks remain open for Phase 2 certification and release hardening.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Task 10 result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 224 passed, 0 failed, 0 skipped |
| Functional UI journeys | 28 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Curriculum accessibility methods | 14 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **479 passed** |

The canonical run used the script's default iPhone 17 Pro simulator destination. No failure, skip, cancellation, or accessibility opt-out was masked. The exact aggregate is `73 + 32 + 38 + 224 + 28 + 28 + 14 + 11 + 31 = 479`.

## DEBUG/Release separation and secret evidence

- Fixture declarations, UI-test dependency construction, and the accessibility5 selector are compile-fenced to DEBUG. Release always selects the Firebase-backed production composition and does not interpret UI-test fixture arguments.
- The canonical environment check built unsigned Debug and Release `iphoneos` app bundles and verified development versus production configuration, bundle identifier, iPhone family, and iOS 17.0 minimum version.
- The Release app-bundle scan found none of the UI-test launch markers, curriculum selector, accessibility5 selector, synthetic never-publish sentinel or encoded sentinel prefix, or synthetic lesson ID. The Release executable symbol scan found no DEBUG UI-test client/composition/curriculum implementation symbol.
- Gitleaks 8.30.1 found no leak across the 28-commit post-implementation local history and the then-current first-party worktree.

This is compile fence, unsigned Release-device build, marker/symbol, and local secret-scan evidence. It is not an App Store-signed archive, notarized distribution artifact, remote-CI provenance, or production configuration/session proof.

## Deliberate non-claims and open work

- `SHIP-FIRST-LESSON` remains incomplete. The destination is read-only and does not start an attempt, capture or score an answer, provide feedback/revision, complete a lesson, or write progress.
- `SHIP-A11Y` remains incomplete. The exact automated boundary is the fresh catalog/preview evidence above; physical VoiceOver, Reduce Motion, Switch Control, device, minimum-runtime, and full SHIP-flow evidence remain open.
- No original learner-facing curriculum was authored. No deep launch specialization was selected, inferred, or recommended.
- No staging or production content was read, authored, published, rolled back, or otherwise mutated as Task 10 evidence. The content-load decision gate remains closed.
- Privacy-safe curriculum route analytics remain Task 11.
- Phase 2 owner approval, original reviewed fixture, staging publish/read/cache/roll-forward/rollback, production-shaped Rules/device evidence, minimum-iOS CI execution, full localization/accessibility certification, and named approvals remain open.
- Task 10 does not complete Phase 2, internal alpha, launch approval, or any Product Bible release gate.

Task 11 is next: add typed privacy-safe curriculum view analytics without allowing curriculum or learner text into event payloads.

Phase 2 remains in progress, and no Product Bible release gate is satisfied.

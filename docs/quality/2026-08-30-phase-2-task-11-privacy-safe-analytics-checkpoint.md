# Syntholo Phase 2 Task 11 privacy-safe analytics checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Task 11 and the mandatory content-load gate

**Implementation commit:** `0234034` (`feat(analytics): add privacy-safe curriculum views`)

**Canonical-runner reliability commit:** `a124267` (`test(ios): retry timed-out accessibility audits`)

**Documentation provenance:** this checkpoint records the two commits above; the documentation commit is identified by Git history

## Result

Phase 2 Task 11 is complete at its typed client-event, validated-route, presentation-lifecycle, Firebase-adapter, and synthetic verification scope. Syntholo now emits `program_viewed`, `module_viewed`, and `lesson_viewed` through typed contexts that can carry only typed curriculum identity/version data, locale, saved/fresh source, and the bounded lesson-duration bucket. Production call sites populate those contexts from entities resolved by `CurriculumStore` in a retained validated snapshot.

The implementation does not add content-sync events or analytics error events. Those were optional under Task 11 and remain outside this checkpoint. It also does not start a lesson, record an answer, score work, write progress, publish curriculum, or satisfy a Product Bible release gate.

## Typed privacy boundary

The analytics API has a closed 17-key allowlist shared by onboarding and curriculum telemetry:

`goal`, `path`, `coach_mode`, `auth_provider`, `restored_session`, `locale`, `catalog_version`, `program_id`, `program_version`, `module_id`, `module_version`, `lesson_id`, `lesson_version`, `rubric_id`, `rubric_version`, `content_source`, and `duration_bucket`.

Curriculum call sites receive only `ProgramViewAnalyticsContext`, `ModuleViewAnalyticsContext`, or `LessonViewAnalyticsContext`. Those contexts contain typed stable IDs, numeric versions, locale, saved/fresh source, and—for a lesson—the actual validated rubric identity/version and one of five closed duration buckets: 1–5, 6–10, 11–20, 21–40, or 41–180 minutes.

Titles, objectives, lesson bodies, questions, options, correct answers, feedback, prompts, submissions, learner answers, email, profile text, operator identity, and arbitrary strings are not fields in these contexts. Tests carry learner-visible curriculum sentinels through the validated snapshot and prove that none appears in event names, keys, or mapped Firebase values. They separately assert the absence of forbidden keys and representative email/profile/operator values; the context type shape, rather than runtime injection of those latter values, makes them unavailable to the production call sites.

Stable IDs and versions remain separate in the Firebase adapter. IDs map to strings; versions and the restored-session flag map to integers. This avoids constructing long composite version IDs and keeps every Firebase value to a string or integer.

This is an API-shape and adapter-mapping guarantee for the implemented call sites. It is not a general proof that future untyped logging, a different analytics SDK, or backend enrichment could never introduce a privacy defect; future event additions must preserve the same closed typed boundary and receive privacy review.

## Validated route identity and freshness

`CurriculumStore.recordPresentation(of:)` accepts a typed Learn route only when its locale and retained catalog snapshot match. The store then resolves the program, module, lesson, and rubric from the already validated snapshot and constructs analytics from those entities. Lexical route tokens are never copied directly into the payload.

The event source is derived from the retained catalog freshness recorded when the snapshot arrived as saved or fresh. Freshness is retained, pruned, and reset with the corresponding catalog snapshot, so a route cannot outlive its provenance or cross a locale/repository replacement.

Invalid, missing, mismatched-locale, pruned, or otherwise unpresentable routes return `false` and emit nothing. Opening a lesson route directly emits only `lesson_viewed`; it does not synthesize program or module views.

## SwiftUI presentation lifecycle

Each valid program, module, or lesson destination applies a destination-local modifier with private `@State`. On first appearance, the modifier marks the presentation before making the synchronous analytics call. SwiftUI body reevaluation therefore cannot duplicate the event. If route resolution rejects the presentation, the state resets so a later valid appearance may try again.

Popping and recreating the destination creates a distinct presentation and may emit another view event. That is intentional: Task 11 defines one event per presentation, not one event for the lifetime of an ID.

The lifecycle tests host the real SwiftUI destinations and exercise appearance/re-evaluation/recreation behavior against a recording client. They are client lifecycle proof, not a live Firebase network capture.

## Root composition and Firebase mapping

Root composition constructs one analytics client and shares it between onboarding and curriculum:

- A configured live composition uses `FirebaseAnalyticsClient`.
- An unconfigured composition uses `NoOpAnalyticsClient` and never pretends delivery is available.
- Exact DEBUG UI-test composition uses one no-op client and retains Task 10's no-Firebase/no-Firestore construction boundary.

The production `CurriculumStore` initializer requires explicit analytics injection. Test-only convenience construction is confined to the test target.

## Focused and build evidence

The settled Task 11 checks passed:

| Evidence | Result |
| --- | ---: |
| Focused analytics tests | 11 passed, 0 failed, 0 skipped |
| Complete Swift unit discovery | 232 passed, 0 failed, 0 skipped |
| Focused program/lesson route UI smoke | 2 passed, 0 failed, 0 skipped |
| Generic iOS Simulator production build | Passed |
| Environment and DEBUG/Release separation | Passed |
| Shell syntax, diff hygiene, and forbidden-field static scan | Passed |
| Independent Task 11 code reviews | No P0/P1/P2 findings |

The focused tests cover exact event names and payloads, all five duration boundaries, saved/fresh provenance, invalid-route rejection, real rubric identity, direct-lesson behavior, body reevaluation, destination recreation, Firebase key/value mapping, curriculum-sentinel exclusion, and forbidden-key/value absence assertions.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed on exact commit `a124267` using the dedicated **Syntholo Canonical iPhone 17 Pro** simulator on iOS 26.5:

| Gate | Task 11 result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 232 passed, 0 failed, 0 skipped |
| Functional UI journeys | 28 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Curriculum accessibility methods | 14 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **487 passed** |

The exact aggregate is `73 + 32 + 38 + 232 + 28 + 28 + 14 + 11 + 31 = 487`. No accessibility opt-out, test retry, failure, skip, or cancellation occurred in this final run.

This checkpoint is the durable record of the observed invocation. The runner creates result bundles under a temporary directory and removes them on exit, so no raw canonical `.xcresult` bundle or transcript was retained. Repository test enumeration and the runner's exact result assertions independently encode the 487-test topology and expected counts, but they are not a substitute for the removed historical bundles. Future release-candidate gates must archive their raw results and machine-readable summary.

Gitleaks 8.30.1 was clean across all 31 local commits then present and the first-party worktree. The environment gate passed with Xcode 26.6, Swift 6.3.3, XcodeGen 2.46.0, Node 22.23.2, npm 10.9.8, Java 21.0.12.1, Firebase CLI 15.28.1, and macOS 26.6.2.

## Simulator incident and runner hardening

Two earlier full invocations exposed CoreSimulator/XCTest launch faults rather than product assertions:

- The default simulator failed to materialize the Profile contrast test bundle from a CoreSimulator `Dead/temp` path. That exact audit passed 1/1 after moving to a dedicated simulator.
- A later dedicated-simulator invocation hit the existing 300-second process watchdog while launching preview element detection. The exact audit passed 1/1 after a clean boot.

Commit `a124267` therefore adds a narrow reliability rule for the 42 per-method accessibility audits: only watchdog exit 124 may retry, only once, and only after an explicitly successful simulator reboot and removal of that audit's partial direct-child result bundle. Non-timeout Xcode/test failures remain terminal, a second timeout remains terminal, and path guards prevent cleanup outside the runner's temporary result directory.

Targeted shell tests cover immediate success, non-timeout failure, timeout then success, timeout twice, timeout then failure, reboot failure, partial-result cleanup, and outside/nested path refusal. An independent review found no P0/P1/P2 issue after a masked-intermediate-reboot-status regression was fixed. The final 487-check canonical invocation did not exercise the retry path.

## Deliberate non-claims

- No production or staging Firebase analytics event was delivered or inspected in DebugView, a dashboard, BigQuery, or a network capture.
- No consent flow, analytics retention period, privacy-policy disclosure, App Privacy answer, deletion propagation, or privacy-owner approval is claimed.
- No content-sync/error event was added.
- No iOS 17 runtime is installed locally. The iOS 17 deployment floor builds, but minimum-runtime CI execution remains open.
- No physical VoiceOver, Reduce Motion, Switch Control, physical-device, or `SHIP-A11Y` proof is claimed.
- No original learner-facing curriculum was authored, and no specialization was selected, inferred, or recommended.
- No staging or production content read/write, publication, rollback, device load, or analytics delivery occurred.
- `SHIP-FIRST-LESSON`, Phase 2 exit, internal alpha, launch approval, and every Product Bible release gate remain incomplete.

## Mandatory content-load gate audit

The post-Task-11 gate is **0 of 4 complete**:

| Required before Task 12 | Status | Repository evidence |
| --- | --- | --- |
| Dated Product Bible choice of School, Work, Creation, or Build | Missing | The Bible still lists this as a Product-owned remaining fill-in; general Bible acceptance is not the missing choice. |
| Tracked `content/config/launch-content-decision.json` matching that choice | Missing | The schema exists, but the decision file is absent and untracked. |
| Staging project ID/number and approved keyless impersonated publisher principals | Missing | `content/config/environments.json` contains only the fixed emulator identity. |
| Product and curriculum authorization for original Foundations authoring and staging load | Missing | No dated authorization record exists; the binding checklist remains unchecked. |

Task 12 and Task 13 staging/content work must therefore stop. Safe synthetic maintenance and independent Phase 1 work may continue, but Phase 2 remains in progress and the content-load gate cannot be waived by implementation.

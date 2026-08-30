# Syntholo iOS — Ordered Project-Finish Execution Report

**Prepared:** August 30, 2026

**Product authority:** [`2026-08-25-syntholo-product-bible.md`](../superpowers/specs/2026-08-25-syntholo-product-bible.md)

**Readiness source:** [`2026-08-30-launch-readiness-report.md`](2026-08-30-launch-readiness-report.md)

**Detailed launch plan:** [`2026-08-30-syntholo-ios-launch-completion-master-plan.md`](../superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md)
**Detailed Phase 2 plan:** [`2026-08-30-syntholo-curriculum-platform.md`](../superpowers/plans/2026-08-30-syntholo-curriculum-platform.md)

## 1. Launch objective

Finish Syntholo 1.0 as a trustworthy, accessible native iPhone school for learners aged 13 and older. A launch build is not complete until a learner can onboard, authenticate, start and finish a real lesson, receive explainable feedback, recover work after interruption, see accurate progress and limits, purchase or restore Pro, use the bounded social system safely, manage or delete their data, and install a signed App Store build backed by approved content and operating procedures.

The immediate product failure remains the same: the onboarding CTA promises a first lesson but currently reaches a placeholder. The critical path therefore starts with curriculum identity and publication, then the real lesson engine, and only then AI, engagement, subscriptions, and social.

## 2. Current standing

| Area | Status | Evidence or remaining gap |
| --- | --- | --- |
| Phase 0 — engineering foundation | **Verified** | Native Swift 6/iOS 17 architecture, four-tab shell, tests, CI definition, accessibility harness, and local secret scanning exist. |
| Phase 1 — identity/onboarding | **Substantially complete** | Onboarding, age gate, goal, experience, path, coach, auth architecture, persistence recovery, and localization hardening exist. Daily goal/settings, live staging auth, iOS 17 CI proof, and physical VoiceOver proof remain. |
| Phase 2 Tasks 1–2 | **Complete** | Frozen curriculum contract, synthetic schema/fixture, canonical digests, validation, Firestore-shape conversion, and secret-scanner foundation; 73 content-contract tests pass. |
| Phase 2 Task 3 | **Complete at emulator scope** | Publisher/rollback and operator identity are preserved at `ec8ac97`; independent security/contract reviews are clear and the uninterrupted 326-test gate passed. Live publication remains a later staging-gate task. |
| Phase 2 Task 4 | **Complete at emulator scope** | Authenticated shallow exact gets, allowed missing-path semantics, list/write/private denial, fixed launch identifier bounds, and the preserved profile contract pass 31/31 Rules tests; no index was added. |
| Phase 2 Task 5 | **Complete** | The pure Swift 6 curriculum domain, closed learner-readable models, strict JSON ingress, RFC 8785/SHA-256 parity, graph validation, typed load boundary, and test-only fixtures are committed at `f3a07ec`; the uninterrupted gate passes 349 tests. |
| Phase 2 Tasks 6–13 | **Not complete** | Cache/repository/store/UI, preview navigation, UI/a11y tests, analytics, approved content, staging, and rollback certification remain. |
| Phases 3–8 | **Missing** | Learning engine, AI coach, engagement, StoreKit, bounded social, settings/data rights/operations, and full launch curriculum remain. |
| Phase 9 | **Not started** | App Store identity/assets, privacy metadata, release matrix, review materials, monitoring, rollback ownership, and submission remain. |

No Product Bible release gate is currently passed. `GATE-ALPHA`, `GATE-TF-CLOSED`, `GATE-TF-EXPANDED`, and `GATE-STORE` must each receive dated evidence and named approval.

## 3. Non-engineering inputs that must be supplied

These inputs can be worked on in parallel, but the associated implementation must stop at the stated boundary until each one is recorded.

1. **Choose the deep launch specialization.** Product must choose exactly one of School, Work, Creation, or Build through Product Bible change control. Engineering must not infer or recommend the choice. This blocks original learner-facing content, any staging/production content write, staging-device content load, and Phase 2 exit.
2. **Approve the Phase 2 contract.** Product, curriculum, iOS, backend, privacy, and accessibility owners must approve the frozen contract.
3. **Provide Firebase environments.** Supply separate development, staging, and production project IDs/numbers, app records, allowed keyless impersonated publisher principals, App Check setup, provider configuration, and least-privilege access.
4. **Provide Apple access.** Apple Developer team, signing, App ID/capabilities, Sign in with Apple, App Store Connect record, subscription products, and sandbox testers are required.
5. **Provide Google auth setup.** Supply the production iOS OAuth client and approved callback/configuration.
6. **Configure source-control operations.** Choose the Git remote/default branch, configure it, protect release/CI branches, and require the canonical gate.
7. **Approve the AI policy.** Name the primary/fallback models, timeout and rate limits, evaluation thresholds, retention rules, and change-control owner before Phase 4 exits.
8. **Approve privacy/legal/support policy.** Record data-retention and deletion periods, privacy policy, terms, support URL/email, subscription language, AI disclosure, age-rating answers, and vendor data-use restrictions.
9. **Name launch owners.** Assign product, engineering, curriculum, privacy, accessibility, support, monitoring, content rollback, backend rollback, and app-release rollback owners.
10. **Define TestFlight policy.** Record cohort sizes, observation windows, support route, stop conditions, and rollback rules before expanded testing.

## 4. Exact implementation order

### Step 1 — Close the current publisher/rollback checkpoint

**Status:** Complete at emulator scope in implementation commit `ec8ac97`; live staging enablement remains the first part of Step 12 and certification remains Step 13.

- Finish deterministic regressions for source-file replacement, fail-closed unsafe REST preference with poisoned ambient Google credentials, non-loopback emulator hosts, foreign SDK/filesystem error redaction, and corrupt historical document identity.
- Prove the source bytes that are scanned are the exact bytes parsed and published.
- Prove the unsafe REST preference and non-loopback endpoints are rejected before Firebase Admin construction or ambient credential lookup, and pin the accepted emulator client to non-REST loopback transport.
- Prove first publish, version-head monotonicity, no-op audit, replay, collision, roll-forward, rollback, repeated rollback, injected failures, transaction budget, and authorization gates.
- Run the publication suite on isolated dynamic emulator ports and record its exact discovered count with zero failure, skip, cancellation, or leaked listener.
- Run the combined content suites, syntax checks, `git diff --check`, the full uninterrupted `./scripts/test.sh`, and full-history/worktree/generated-output/built-app secret scans.
- Review and commit only the intended publisher/config/test/setup changes.
- Create a dated Phase 2 Task 3 checkpoint that records RED/GREEN evidence, security findings and fixes, exact totals, scans, and known limits.

**Done when:** The emulator-only operator path is committed, independently reviewed, reproducibly green, and cannot perform a live write. No original curriculum and no staging/production write may be introduced here.

### Step 2 — Finish the remaining Phase 1 baseline in parallel

- Add daily-goal selection/default and an editable settings destination.
- Configure development and staging Firebase apps without committing local credentials.
- Verify Apple, Google, and email/password on a physical device.
- Test cancellation, provider error, offline behavior, duplicate email, expired credential, sign-out, relaunch, returning-user recovery, and account switching.
- Keep Apple equally available wherever Google login is offered.
- Run the canonical suite on the minimum iOS 17 simulator in CI.
- Complete physical-device VoiceOver checks across every onboarding/auth/handoff step.

**Done when:** A new and returning eligible learner can authenticate against staging, recover preferences, edit the daily goal/settings, and complete the critical flow on iOS 17 and current iOS without data loss or a critical accessibility defect.

### Step 3 — Add curriculum Firestore Rules (Phase 2 Task 4)

**Status:** Complete at emulator scope in implementation commit `5e94dc0`; production-shaped staging Rules proof remains part of Step 13 certification.

- Write failing Rules tests first.
- Allow authenticated exact `get` only for shallow, valid, published learner-readable documents.
- Deny unauthenticated reads, all broad `list` queries, drafts, malformed/unknown shapes, private evaluation contracts, audit records, and authoring namespaces.
- Deny every client create/update/delete across configuration, pointers, versions, assets, rubrics, heads, private contracts, and audit.
- Preserve all existing profile protections and the final catch-all deny.
- Keep graph/digest/deep validation in Node and Swift rather than pretending Rules prove it.
- Update and freeze the exact Rules test count.

**Done when:** Authenticated exact reads work, missing allowed records return not-found, every unauthorized/private/write case fails, and no new broad index/query surface is added.

### Step 4 — Implement the Swift curriculum domain (Phase 2 Task 5)

**Status:** Complete in implementation commit `f3a07ec`; see [`2026-08-30-phase-2-task-5-swift-domain-checkpoint.md`](2026-08-30-phase-2-task-5-swift-domain-checkpoint.md). Task 6 is next.

- Add stable/locale/version identifiers and exact `Codable`, `Equatable`, `Hashable`, and `Sendable` curriculum models.
- Implement the same canonical JSON/digest and validation semantics used by Node.
- Add the closed block/completion unions and exact compatibility checks.
- Add the `AsyncStream<CurriculumLoadEvent>` repository boundary.
- Keep protected evaluation data, Firebase SDK types, filesystem types, SwiftUI, and authoring-only rights workflow out of the core domain.
- Use the shared synthetic fixtures and digest vectors only as test resources, never app resources.

**Done when:** Node and Swift produce identical validation/digest results and strict-concurrency focused tests pass.

### Step 5 — Build the app-owned curriculum cache (Phase 2 Task 6)

- Implement an actor-backed cache with atomic replacement.
- Namespace by environment, project, and locale.
- Revalidate the complete graph before returning or replacing a snapshot.
- Quarantine corrupt, incompatible, wrong-envelope, malformed, or digest-invalid data deterministically.
- Preserve the last valid snapshot after failed reads, writes, or quarantine operations.

**Done when:** Valid cached curriculum survives relaunch and every expected local failure without crossing environments or deleting another valid snapshot.

### Step 6 — Build the exact-get Firestore repository (Phase 2 Task 7)

- Resolve configuration, locale catalog, pinned program versions, modules, lessons, rubrics, and assets through authenticated exact gets.
- Never resolve a snapshot through mutable program pointers, list queries, audit documents, or protected evaluation contracts.
- Force a server refresh, validate the entire graph, and replace cache only after full success.
- Implement saved → fresh, saved → unavailable/stale, saved → update-required, and no-cache empty/unavailable behavior.
- Cover missing targets, unsupported locale/schema/client version, offline, cancellation, malformed values, digest failure, duplicate suppression, and order preservation.
- Isolate non-`Sendable` Firebase SDK values behind the established store pattern.

**Done when:** The adapter emits the exact event order, never exposes partial/incompatible data, and preserves a valid fallback when the remote path fails.

### Step 7 — Replace the Learn placeholder with read-only curriculum UI (Phase 2 Task 8)

- Add `@MainActor @Observable` curriculum state with narrow, equatable UI state and ignored dependencies/tasks.
- Render loading, saved/stale, empty, update-required, unavailable, retry, and fresh states.
- Render ordered catalog, program, module, and lesson rows using stable IDs.
- Render a read-only lesson preview with objective, duration, concept, diagram/text alternative, question, and non-sensitive rubric/version metadata.
- Keep fixed interface text in `Localizable.xcstrings` and support iOS 17 without unguarded newer APIs.
- Do not add answer controls, correct answers, scoring, completion, progress, AI, or paywall behavior in this step.

**Done when:** Real validated versioned records replace the Learn placeholder and every state is testable, localized, and accessible.

### Step 8 — Connect the same-session first-preview handoff (Phase 2 Task 9)

- Add a typed route retaining locale, catalog, program, module, lesson, and rubric versions.
- Build curriculum dependencies once in root composition; do not inject Firestore into onboarding.
- While resolving, remain on the handoff, disable duplicate taps, and expose accessible loading.
- On failure without cache, remain on the handoff and offer retry.
- On success, install the exact Learn preview route before entering the signed-in shell.
- Label the action **Preview the first lesson** until Phase 3 implements a real lesson-start mutation.
- Do not show catalog, paywall, notification, or social UI before the preview.

**Done when:** The same onboarding session opens the exact immutable preview, while `SHIP-FIRST-LESSON` remains honestly incomplete until Phase 3.

### Step 9 — Add deterministic UI fixtures and end-to-end coverage (Phase 2 Task 10)

- Add debug-only in-memory fixtures for fresh, saved, saved → fresh, offline/no cache, incompatible with/without fallback, empty, malformed, and fail-once/retry.
- Guarantee `--ui-testing` never contacts Firestore.
- Test onboarding → exact preview and catalog → program → module → preview.
- Test that no catalog/paywall/notification/social interruption precedes the onboarding preview.
- Add accessibility audits for every curriculum state and preview.
- Discover and record exact unit, functional UI, and accessibility totals only after the final green run.

**Done when:** The curriculum UI is deterministic, has no live test dependency, and the canonical gate reports zero failure, skip, or cancellation.

### Step 10 — Add privacy-safe curriculum analytics (Phase 2 Task 11)

- Add typed `program_viewed`, `module_viewed`, and `lesson_viewed` events.
- Limit payloads to stable IDs, locale, source/freshness, duration bucket, and safe error code.
- Make lesson title/body/question/options/answer/feedback, prompt/submission, email/profile text, and operator fields impossible to place in the typed payload.
- Emit one event per route presentation, not per SwiftUI body evaluation.

**Done when:** Tests prove no curriculum or learner text can enter analytics and all payloads comply with `LAW-19`.

### Step 11 — Pass the mandatory content-load decision gate

Stop before original content or staging writes unless all four items are complete:

- Product Bible contains a dated accepted specialization: School, Work, Creation, or Build.
- A tracked `content/config/launch-content-decision.json` validates and matches that Bible decision exactly.
- The approved staging project ID/number and keyless publisher principals are allowlisted.
- Product and curriculum owners authorize original Foundations fixture authoring and staging load.

**Done when:** Every decision/access record is tracked and approved. There is no implementation override for this gate.

### Step 12 — Enable the approved staging path, then author the first reviewed Foundations fixture (Phase 2 Task 12)

- Only after Step 11 passes, extend the constrained operator command to staging: construct live Firestore only for the allowlisted staging project, use keyless ADC impersonation, derive and verify the actual principal/project ID/project number through authenticated metadata, and reject direct user ADC, service-account key JSON, development, production, mismatched confirmation, and unapproved identities before Firestore construction.
- Apply the least-privilege publisher role, retain the underlying impersonator in Cloud Audit Logs, keep safe-output/source-scan/transaction semantics identical to emulator mode, and add deterministic authorization and disguised-production regressions.
- Write fixture-specific failing tests first.
- Author one original Foundations program, one module, and one structurally valid read-only lesson preview.
- Include objective, duration, completion rule, prerequisites, concept, original diagram and text alternative, rights metadata, applied single-answer check, deterministic feedback, public scoring/rubric data, and a matching protected evaluation contract.
- Include catalog membership and the exact first-lesson pointer.
- Complete curriculum, copyright/rights, safety, and accessibility review.
- Keep authoring drafts outside the app target/resources.

**Done when:** The live operator path proves the approved staging identity and least privilege without accepting a key file or production target; the reviewed fixture validates; and its staging dry-run exposes only safe metadata and performs no write. Do not call this a complete Product Bible lesson; response capture, revision, outcomes, and progress come in Phase 3.

### Step 13 — Certify Phase 2 on staging (Phase 2 Task 13)

- Complete VoiceOver, Dynamic Type, Switch Control, Reduce Motion, target-size, non-color status, text-alternative, and localization checks.
- Run the complete gate on current iOS and minimum iOS 17 CI.
- Review staging dry-run, publish v1 with an approved keyless principal, and verify exact device load/cache/relaunch/refresh.
- Publish a safe v2, prove v1 remains immutable, reject selecting v1 through publish, roll back through the rollback operation, and prove the app resolves v1.
- Verify authenticated exact reads and all learner/private writes denied under production-shaped Rules.
- Scan full Git history, worktree, logs/reports, generated files, and the built `.app`.
- Record commands, versions, exact totals, IDs/digests, derived principal, operation/audit IDs, screenshots/recordings, approvals, rollout, rollback, and known defects.

**Done when:** The dated Phase 2 evidence report proves the complete immutable publish → exact sync/cache → preview → roll-forward → rollback path with no open P0/P1 integrity, exposure, credential, crash, or critical accessibility defect.

### Step 14 — Build the real learning engine (Phase 3)

1. Write the Phase 3 contract for activity, lesson, attempt, sync, entitlement, allowance, learner-day, and reconciliation state.
2. Assign a stable attempt ID before submission.
3. Implement concept/scroll, single-answer, multi-select, one matching/ordering interaction, prompt builder/revision, feedback/results, and captioned video or accessible still equivalent.
4. Implement deterministic objective scoring against the immutable published answer contract.
5. Persist attempts/responses before rewards and make completion, XP, mastery, and rewards server-authoritative and idempotent.
6. Enforce three new free lesson starts per learner-day; resume/retry/review/revision must not consume another credit.
7. Build a durable queue for draft, pending, submitting, acknowledged, retryable/permanent failure, and reconciled states.
8. Preserve work across backgrounding, kill/relaunch, crash, network loss, auth expiry, timeout, duplicate response, and supported offline use.
9. Replace **Preview the first lesson** with a real **Start the first lesson** mutation, resume path, results, progress, and next lesson.

**Done when:** A complete module works online, after interruption/relaunch, and in supported offline cases with no lost work, duplicate allowance use, duplicate rewards, or content-version mismatch.

### Step 15 — Build and certify the AI coach (Phase 4)

- Write the teen/privacy threat model and keep all model calls in authenticated server code.
- Verify auth, App Check, entitlement/rate limit, content/rubric version, attempt state, and allowance before evaluation.
- Moderate input, load the immutable rubric, request strict structured scoring, and validate criteria/ranges/totals/version on the server.
- Store the validated score independently from presentation tone.
- Render Supportive, Funny, Strict, Chill, and Socratic feedback from the same score and prove tone invariance.
- Support one free revision and three free follow-ups per scored attempt; Pro receives the approved expanded limits.
- Preserve learner work across moderation rejection, timeout, model outage, invalid schema, auth expiry, rate limit, offline, and retry.
- Run a versioned adversarial/safety/schema/tone/cost/latency evaluation suite for primary and fallback models.

**Done when — `GATE-ALPHA`:** Onboarding → real lesson → objective/AI feedback → progress sync → kill/relaunch → supported offline recovery passes as one flow, Rules deny protected writes, the privacy threat model is approved, and no progress-loss or duplicate-reward defect remains.

### Step 16 — Build daily engagement (Phase 5)

- Build Today with mission, continue/next lesson, allowance, streak, XP, mastery/review needs, and next preview.
- Replace Learn and Practice placeholders with real catalog/progress/review/challenge/history states.
- Award XP and streaks only from acknowledged learning events and reconcile offline work without duplicate rewards.
- Add all-complete, stale, offline, retry, and version-mismatch states.

**Done when:** The daily loop is accurate across relaunch, supported second device, offline reconciliation, and duplicate server delivery.

### Step 17 — Build StoreKit 2 subscriptions (Phase 6)

- Configure monthly/annual products and the approved seven-day annual trial in one subscription group.
- Display StoreKit-localized price/period and complete trial/renewal/cancellation disclosures.
- Verify transactions before access, reconcile signed evidence with the backend, listen for updates, restore purchases, and link manage-subscription.
- Implement free, trial, active, grace/retry, pending, canceled-active, expired, revoked/refunded, verification-failed, offline/stale, and backend-mismatch states.
- Resume the interrupted fourth lesson only after verified purchase.
- Prove Pro never changes grading, mastery, XP, or social standing.

**Done when:** The complete StoreKit sandbox, restore, refund, expiry, reinstall, account/device change, pending, billing, and stale/offline matrix passes without entitlement bypass or duplicate purchase.

### Step 18 — Build bounded 1.0 social (Phase 7)

- Make social opt-in and teen defaults stricter.
- Add exact handle lookup/invite, friend requests, accept/decline/cancel/remove, and approved preset reactions.
- Add report and block/unblock with immediate required cache removal and backend intake.
- Test enumeration resistance, unauthorized reads/writes, races, repeated requests, offline caches, and moderation ownership.
- Do not add discovery feeds, DMs, comments, free text, leagues, leaderboards, team quests, or shared streaks.

**Done when — `GATE-TF-CLOSED`:** Phases 5–7, StoreKit sandbox, device accessibility, privacy/terms/support, and retention baselines pass with zero open critical security, safety, purchase, accessibility, or data-loss defect.

### Step 19 — Complete profile, data rights, launch content, and operations (Phase 8)

- Build Profile/Settings for account, age-safe public profile, learning preferences, path, coach, daily goal, notifications, membership, restore/manage, downloads, privacy/safety, blocked users, support, policies, version, and sign-out.
- Implement authenticated account deletion and data export end to end, including retry, partial failure, vendor/backups propagation, secure delivery/expiry, and audit.
- Finish production Auth, Firestore, Functions, Storage, App Check, Remote Config, Messaging, Analytics, and Crashlytics with least privilege.
- Add logs, dashboards, alerts, correlation IDs, rate/cost controls, and incident/runbook coverage without sensitive payloads.
- Publish and editorially certify Foundations with at least 3 modules, 12 lessons, and 1 capstone; the chosen specialization with at least 2 modules and 8 real lessons; and three honest specialization shells.
- Load-test starts/completions, progress, AI bursts, subscription reconciliation, deletion/export, and outage/rollback behavior.

**Done when — `GATE-TF-EXPANDED`:** Every launch lesson has editorial/safety/rights/accessibility QA; data rights, notifications, downloads, and operations work end to end; reliability approaches the 99.8% crash-free target; and no P0/P1 launch defect remains.

### Step 20 — Certify, sign, and submit Syntholo 1.0 (Phase 9)

- Finish final icon, launch appearance, display name, category, age rating, version/build scheme, and copyright.
- Complete privacy manifest/required-reason APIs, App Privacy labels, localized subscription/legal/support metadata, screenshots, and preview assets showing only shipping features.
- Run minimum/current iOS on representative smallest/largest iPhones and physical VoiceOver, Dynamic Type, Switch Control, Reduce Motion, contrast, target, caption/transcript, focus, and orientation checks.
- Run fresh-install, upgrade, kill/relaunch, reinstall, account switch, second-device, network/failure, live auth, StoreKit, allowance, learner-day, revision/follow-up, download, social safety, deletion/export, notification, and support matrices.
- Prove the signed bundle contains no secret, debug endpoint, sensitive log, or unrestricted protected write.
- Prepare reviewer account/data and review notes for lesson, AI, purchases, restore/manage, social safety, and deletion.
- Activate dashboards/alerts and name the release commander, support/incident contacts, and content/backend/app rollback owners.
- Freeze app/content versions, exercise rollback, meet TestFlight observation policy and reliability thresholds, obtain cross-functional sign-off, upload, and submit.

**Done when — `GATE-STORE`:** The signed release commit has a zero-skip canonical pass; crash-free sessions are at least 99.8%; visible AI failure is below the approved limit; there is no open P0/P1; App Review can use the core product, purchase/restore/manage, and delete an account; and all owners sign the dated evidence.

## 5. The next ten concrete actions

1. Implement Task 6: the environment/project/locale-namespaced app-owned cache with atomic replacement and deterministic quarantine.
2. Implement Task 7: the authenticated exact-get Firestore repository with saved-first event ordering and complete graph validation.
3. In parallel, configure the Git remote/branch protection, minimum-iOS CI runtime, and development/staging Firebase access.
4. Obtain the six-owner Phase 2 contract approval.
5. Implement Task 8: the observable curriculum store and honest Learn catalog/program/module/read-only lesson states.
6. Implement Task 9: the same-session first-preview handoff with exact version identity.
7. Implement Tasks 10–11: deterministic UI/accessibility coverage, then privacy-safe analytics.
8. Product records the specialization and environment owners provide the approved staging identity gate.
9. Author and cross-functionally review the original Foundations fixture only after that gate.
10. Complete staging publication, device sync/cache, roll-forward, rollback, accessibility, and secret-scan certification.

Do not start Phase 3 implementation until the immutable Phase 2 content identity and staging path are proven. Do not start Phase 4 AI scoring until Phase 3 attempt/rubric/version semantics are proven.

## 6. Required evidence discipline

Every phase/gate checkpoint must include:

- implementation commit and clean-worktree status;
- environment/tool/OS versions;
- exact test counts with zero unexpected failure, skip, or cancellation;
- current and minimum-iOS results;
- negative authorization, integrity, interruption, offline, replay/idempotency, and accessibility evidence appropriate to the phase;
- full Git-history, worktree, generated-output, and built-app secret scans;
- screenshots/recordings for critical user journeys;
- open-defect list and P0/P1 disposition;
- approved identifiers/digests/operation IDs without sensitive learner or credential material;
- named product, engineering, curriculum, privacy, accessibility, support, and release approvals at the relevant gate;
- rollback/stop procedure and responsible owner.

## 7. Scope guardrails for 1.0

Do not expand the launch scope without an approved Product Bible change. Syntholo 1.0 does not require leagues, leaderboards, team quests, shared streaks, free-text social, comments, direct messages, complete depth for all five paths, accredited certificate claims, Android, a learner web app, mandatory iPad optimization, or a visual rewrite that delays the real learning loop.

## 8. Final launch definition of done

The project is finished only when all twenty steps above are complete and all four release gates have dated evidence. Passing simulator tests alone is insufficient: the final state must include approved curriculum, live provider/device proof, verified backend authority and security, physical accessibility sign-off, StoreKit entitlement proof, data deletion/export, legal/support assets, operational monitoring and rollback, a scanned signed build, App Review materials, and cross-functional approval.

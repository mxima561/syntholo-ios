# Syntholo iOS Launch Completion Master Plan

**Created:** August 30, 2026  
**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`  
**Source audit:** `docs/quality/2026-08-30-launch-readiness-report.md`  
**Target:** A launch-ready Syntholo 1.0 that passes `GATE-ALPHA`, `GATE-TF-CLOSED`, `GATE-TF-EXPANDED`, and `GATE-STORE`.

## 1. What “finished” means

The project is finished only when a 13+ learner can:

1. Complete onboarding and create an account.
2. Start a real Foundations lesson in the same session.
3. Learn, answer, receive explainable feedback, revise when allowed, and finish the lesson.
4. Recover their work after interruption, authentication expiry, sync failure, AI failure, or supported offline use.
5. See accurate progress, mastery, XP, streak, next action, and free allowance.
6. Purchase or restore Pro through verified StoreKit 2 transactions.
7. Use the bounded 1.0 social system safely.
8. Manage settings, downloads, privacy, export, deletion, and support.
9. Use the critical product flows with assistive technologies.
10. Install the signed App Store build with approved content, legal assets, monitoring, and rollback operations in place.

The current app is not at this point. Phase 0 is verified, Phase 1 is substantially complete, and Phases 2–9 remain. The most important broken promise is that **“Start the first lesson” currently opens a placeholder instead of a lesson**.

## 2. Execution rules

These rules apply to every task below.

- The Product Bible wins over this document if the two conflict.
- Finish work in dependency order. Do not begin AI scoring before the content/rubric contract is proven.
- Start every new phase with a phase-specific implementation plan traced to Product Bible IDs.
- Add failing tests before new behavior where technically feasible.
- Build loading, empty, error, offline, retry, interruption, and accessibility states with the happy path.
- Use stable identifiers. Never identify an attempt, reward, allowance mutation, transaction, or content version by screen position.
- Keep allowance, reward, mastery, entitlement, and publication decisions server-authoritative and idempotent.
- Do not ship OpenAI keys, Firebase service credentials, App Store secrets, or other server secrets in the client or repository.
- Do not log lesson answers, submissions, prompts, raw coach transcripts, email, or private profile text (`LAW-19`).
- Store all learner-facing text in String Catalogs. Do not rely on runtime conversion of fixed enum strings.
- Support iPhone and iOS 17. Any newer visual API needs an availability-gated iOS 17 fallback.
- A phase cannot exit with an open data-loss, entitlement-bypass, unsafe-AI, critical accessibility, security, or privacy defect.
- Record evidence for every gate in `docs/quality/`; a claim without reproducible evidence is not a passed gate.

## 3. Decisions and access that must be resolved

These are product or operational inputs, not implementation details. Assign an owner and record the decision in the Product Bible before the listed blocker.

| Decision or access | Required result | Blocks |
| --- | --- | --- |
| Deep launch specialization | Choose School, Work, Creation, or Build. **Recommended: AI for School**, because it matches the current audited onboarding path and the online-school product context. | Phase 2 production content |
| Firebase environments | Separate development, staging, and production projects; approved bundle/app records; provider credentials; least-privilege service access. | Live Phase 1 tests and every backend phase |
| Apple Developer access | Team, signing, App ID, capabilities, Sign in with Apple, App Store Connect app, sandbox testers. | Device auth, StoreKit, TestFlight |
| Google auth setup | Production iOS OAuth client and approved callback/configuration. | Phase 1 exit |
| AI model policy | Primary model, fallback model, rate limits, timeout budget, evaluation threshold, and change-control owner. | Phase 4 exit |
| Retention policy | Approved periods for prompts, attempts, saved feedback, diagnostics, exports, moderation evidence, and deletion propagation. | `GATE-TF-CLOSED` |
| Legal and support | Privacy policy, terms, support URL/email, age-rating answers, subscription wording, AI disclosure. | `GATE-TF-CLOSED` / `GATE-STORE` |
| TestFlight policy | Cohort sizes, observation windows, tester support route, stop/rollback rules. | `GATE-TF-EXPANDED` |
| Launch owners | Named product, engineering, curriculum, privacy, accessibility, support, monitoring, and rollback signatories. | `GATE-STORE` |

## 4. Exact implementation order

### Stage 0 — Preserve and close the existing baseline

**Outcome:** The verified foundation and onboarding become a reliable base for the learning product.

#### Step 0.1 — Establish source-control provenance

- [ ] Restore or initialize the intended Git repository without overwriting current files.
- [ ] Confirm the correct remote, default branch, ignore rules, and secret-scanning policy.
- [ ] Commit or otherwise preserve the audited baseline before feature work.
- [ ] Protect CI-required branches and require the canonical gate.

**Proof:** A clean, traceable baseline exists and secrets are not tracked.

#### Step 0.2 — Lock the canonical quality baseline

- [ ] Keep `./scripts/test.sh` green: 98 unit, 16 functional UI, 28 AppShell accessibility, 10 onboarding accessibility, and 20 Firestore Rules tests at the current baseline.
- [ ] Run the suite on the minimum iOS 17 simulator in CI and the current iOS simulator.
- [ ] Record the Xcode debugger warning as tooling noise only while tests remain unskipped and passing.
- [ ] Review the five moderate npm development-tool vulnerabilities without using a forced incompatible downgrade.

**Proof:** A dated baseline report includes test counts, OS/runtime versions, and zero failed/skipped/cancelled tests.

#### Step 0.3 — Remove Phase 1 reliability debt

- [ ] Replace silent `try?` onboarding draft save/clear behavior with typed, recoverable persistence state.
- [ ] Tell the learner when a local choice could not be saved and offer retry without losing selections.
- [ ] Replace runtime localization conversion for fixed enum copy with `LocalizedStringResource` or equivalent compile-time catalog entries.
- [ ] Move intended uppercase presentation into localized catalog copy instead of runtime `.textCase(.uppercase)`.
- [ ] Add daily-goal selection/default and an editable settings destination.
- [ ] Keep experience level separate from coach personality and grading.

**Proof:** Persistence-failure, relaunch, localization, and daily-goal tests pass.

#### Step 0.4 — Finish live identity verification

- [ ] Configure development and staging Firebase apps.
- [ ] Verify Sign in with Apple, Google, and email/password on a physical device.
- [ ] Test cancel, provider error, offline, duplicate email, expired credential, sign-out, relaunch, and returning-user states.
- [ ] Confirm Apple remains equally available whenever Google login is offered.
- [ ] Perform physical VoiceOver checks for age, goal, experience, path, coach, account, and first-lesson handoff.

**Exit — Phase 1 complete:** A new and returning eligible learner can authenticate and recover onboarding preferences with live staging services and no data-loss path.

---

### Stage 1 — Build the curriculum platform (Phase 2)

**Outcome:** An authorized operator can publish immutable curriculum versions, and the app can safely sync and render them.

#### Step 1.1 — Author and approve the Phase 2 contract

- [ ] Write `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`.
- [ ] Trace every schema and workflow to `SHIP-CONTENT`, `SHIP-FOUNDATIONS`, `SHIP-ONE-PATH`, `SHIP-SHELLS`, `SHIP-FORMATS`, and the Product Bible data model.
- [ ] Record the chosen deep specialization.
- [ ] Define content identity, publication state, compatibility version, completion rule, prerequisite, asset, objective, rubric, and rollback semantics.

**Proof:** Product, curriculum, iOS, and backend owners approve the contract before production content entry.

#### Step 1.2 — Implement immutable versioned content

- [ ] Add domain and backend models for `programs`, `programVersions`, `modules`, `lessonVersions`, rubrics, objectives, assets, and feature configuration.
- [ ] Make published lesson and rubric versions immutable.
- [ ] Make edits create a new draft/version rather than mutating published learner history.
- [ ] Store explicit schema and minimum-client compatibility versions.
- [ ] Define stable ordering without using array offsets as identity.
- [ ] Validate broken references, missing objectives/rubrics, inaccessible prerequisites, invalid completion rules, and unsupported block types before publication.

#### Step 1.3 — Build the private operator path

- [ ] Create a constrained private workflow to draft, validate, preview, publish, deprecate, and roll back content.
- [ ] Restrict all publication operations to authorized operator roles.
- [ ] Add an audit trail containing actor, timestamp, version, and action.
- [ ] Ensure rollback selects an already-valid immutable version rather than rewriting history.
- [ ] Add Firestore Rules and server tests proving learners cannot publish or alter protected content.

#### Step 1.4 — Implement iOS curriculum sync

- [ ] Add narrow repositories/services for catalog metadata, content versions, assets, and sync state.
- [ ] Cache the last valid compatible version and preserve it when sync fails.
- [ ] Surface loading, empty, stale, incompatible-version, offline, and retry states.
- [ ] Make version mismatch recovery explicit; never silently score one version against another rubric.
- [ ] Render Learn catalog, program detail, module detail, and a read-only lesson preview using real versioned records.

#### Step 1.5 — Publish the first vertical fixture

- [ ] Publish one immutable Foundations program containing a module and a complete first lesson.
- [ ] Include objective, expected duration, completion rule, concept/still diagram, one deterministic question, asset references, and rubric/version references.
- [ ] Sync that fixture into the app and open it from the existing first-lesson handoff.
- [ ] Track safe content-sync and lesson-view events without learner answers.

**Exit — Phase 2 complete:** The private publisher can publish and roll back a validated fixture, unauthorized writes fail, and the app renders the correct compatible immutable version online and from cache.

---

### Stage 2 — Build the learning engine (Phase 3)

**Outcome:** A learner can complete a full module through interruption and supported offline recovery without duplicate rewards or lost work.

#### Step 2.1 — Author the player and attempt contracts

- [ ] Write the Phase 3 implementation plan after the Phase 2 fixture is proven.
- [ ] Define activity state, lesson state, attempt state, sync state, entitlement state, and allowance state separately.
- [ ] Assign a stable attempt ID before the learner submits work.
- [ ] Define server-authoritative start, completion, mastery, XP, credit-consumption, retry, and reconciliation semantics.
- [ ] Define the exact learner-day boundary using server reconciliation.

#### Step 2.2 — Build required lesson formats

- [ ] Concept/scroll lesson.
- [ ] Objective single-answer quiz.
- [ ] Objective multi-select quiz.
- [ ] One interactive type: matching or ordering.
- [ ] Prompt builder and prompt revision.
- [ ] Feedback and results screens.
- [ ] Short captioned video with transcript, or a still-diagram equivalent when no video exists.
- [ ] Accessible labels, focus order, state announcements, non-color feedback, 44-point targets, Dynamic Type, and Reduce Motion behavior for every format.

#### Step 2.3 — Implement deterministic objective scoring

- [ ] Score objective activities against the published versioned answer contract.
- [ ] Explain correct/incorrect state without exposing hidden security-sensitive keys.
- [ ] Persist the attempt and learner response recovery record before applying rewards.
- [ ] Make completion, XP, mastery, and rewards idempotent under retries and duplicate delivery.
- [ ] Never let a newer lesson/rubric version rewrite completed historical results.

#### Step 2.4 — Enforce the free-start allowance

- [ ] Show remaining allowance before the learner reaches the limit.
- [ ] Allow at most three newly started lessons per free learner-day.
- [ ] Consume one credit only after the authenticated server authorizes a new lesson start.
- [ ] Do not consume another credit to resume the same lesson, retry sync, revise work, review, or re-open a completed lesson.
- [ ] Require Pro or the next learner-day before a fourth newly started lesson.
- [ ] Protect allowance mutations with Rules/App Check and idempotency keys.

#### Step 2.5 — Build the durable local queue and offline behavior

- [ ] Use explicit queue states such as local draft, pending, submitting, acknowledged, retryable failure, permanent failure, and reconciled.
- [ ] Save work continuously and before navigation/backgrounding.
- [ ] Recover after kill/relaunch, crash, network loss, auth expiry, timeout, and duplicate response.
- [ ] Let free learners complete already-started cached lessons offline; require online allowance verification for another start.
- [ ] Prepare Pro download/start behavior without granting it until verified entitlement exists.
- [ ] Mark AI, social, and purchases as online-only.

#### Step 2.6 — Replace the placeholder learner loop

- [ ] Make “Start the first lesson” open and begin the real Foundations lesson.
- [ ] Add resume/continue behavior after relaunch.
- [ ] Replace Learn and Practice placeholders only where supported by real progress data.
- [ ] Show results, progress update, and the next lesson preview.
- [ ] Test a complete module online, under interruption, and through supported offline recovery.

**Exit — Phase 3 complete:** A real module completes without progress loss, duplicate allowance use, duplicate rewards, or version mismatch across online, retry, relaunch, and supported offline cases.

---

### Stage 3 — Build the AI coach (Phase 4)

**Outcome:** AI-evaluated work receives safe, rubric-grounded, explainable feedback whose score does not change with coach tone.

#### Step 3.1 — Author the AI boundary and threat model

- [ ] Write the Phase 4 implementation plan and privacy threat model for teens, prompts, stored work, and vendors.
- [ ] Keep every OpenAI call in authenticated server code; no direct client calls or client secret.
- [ ] Verify auth, App Check, entitlement/rate limit, content version, attempt state, and allowance before evaluation.
- [ ] Apply the approved retention/minimization policy and restrict staff access.

#### Step 3.2 — Implement scoring as a strict pipeline

- [ ] Moderate input before evaluation and handle rejection safely.
- [ ] Load the immutable rubric/version associated with the attempt.
- [ ] Request a strict structured scoring result with criterion scores, evidence, improvement, and next action.
- [ ] Validate the schema, score ranges, criteria, totals, and version references on the server.
- [ ] Reject or retry invalid structured output without losing the learner response.
- [ ] Store the validated scoring result independently of presentation tone.

#### Step 3.3 — Implement the separate tone renderer

- [ ] Render Supportive, Funny, Strict, Chill, and Socratic feedback from the same validated score object.
- [ ] Make AI identity visible and avoid human-teacher impersonation.
- [ ] Preserve criterion, evidence, improvement, and next action in every mode.
- [ ] Add automated invariance tests proving all five tones produce the same score/pass/mastery result.
- [ ] Prevent Remote Config from changing rubrics, safety rules, or entitlement checks.

#### Step 3.4 — Implement revision, follow-up, and fail-soft behavior

- [ ] Free learners receive one revision per AI-evaluated activity; Pro receives unlimited revisions within abuse/rate limits.
- [ ] Free learners receive three follow-up questions per scored attempt; Pro receives unlimited follow-ups within abuse/rate limits.
- [ ] Revisions and follow-ups do not consume new-lesson credits.
- [ ] Add visible moderation, timeout, model-unavailable, invalid-schema, rate-limit, auth-expired, offline, and retry states.
- [ ] Preserve the original response and attempt through every expected failure (`LAW-11`).
- [ ] Provide deterministic fallback/retry copy without inventing a score when validation fails.

#### Step 3.5 — Certify the AI pipeline

- [ ] Create a versioned evaluation suite with normal, edge, adversarial, teen-safety, prompt-injection, malformed-output, and tone-invariance cases.
- [ ] Test primary and fallback models against the approved thresholds.
- [ ] Record latency, visible failure rate, schema failure rate, moderation behavior, and cost without sensitive payloads.
- [ ] Require approval before changing model, rubric, scoring schema, or fallback behavior in production.

**Exit — `GATE-ALPHA`:** Phases 0–4 pass as one flow: onboarding → real lesson → objective/AI feedback → progress sync → kill/relaunch → supported offline recovery. Security Rules deny protected writes, the AI schema suite passes, the privacy threat model is approved, and there is no known progress-loss or duplicate-reward defect.

---

### Stage 4 — Build daily engagement (Phase 5)

**Outcome:** The app gives a trustworthy daily next action and learning-oriented motivation.

#### Step 4.1 — Implement Today and progression

- [ ] Build Today with daily mission, continue/next lesson, allowance counter, streak, XP, mastery/review needs, and next preview.
- [ ] Build programs catalog, path switcher, program/module details, and honest shell states from versioned content.
- [ ] Keep Foundations first; preview specialization after the first Foundations lesson.
- [ ] Compute progress from acknowledged server state while displaying pending local work honestly.

#### Step 4.2 — Implement engagement mechanics

- [ ] Award XP idempotently from verified learning events.
- [ ] Increment streak on a learner-day with at least one completed lesson or completed daily mission.
- [ ] Never sell streak protection or mark an uncompleted lesson complete.
- [ ] Add daily challenge, objective review, spaced-practice queue, saved feedback, and history.
- [ ] Reconcile pending/offline results without double rewards or sudden silent reversals.

#### Step 4.3 — Replace remaining learning placeholders

- [ ] Learn tab contains real Today/catalog/progress states.
- [ ] Practice tab contains real review/challenge/history states.
- [ ] Loading, empty, all-complete, offline, stale, retry, and version-mismatch states are usable and accessible.
- [ ] Validate engagement analytics without raw learner content.

**Exit — Phase 5 complete:** The daily loop survives relaunch and another supported device, and rewards remain correct under offline reconciliation and duplicate server delivery.

---

### Stage 5 — Build subscriptions and entitlements (Phase 6)

**Outcome:** The free limit and Pro access are honest, verifiable, restorable, and resilient.

#### Step 5.1 — Configure StoreKit products

- [ ] Create one auto-renewable subscription group.
- [ ] Configure monthly and annual products using final App Store product identifiers.
- [ ] Configure the annual seven-day trial and approved eligibility behavior.
- [ ] Display StoreKit localized price and period; do not hard-code USD as the purchase price.
- [ ] Present trial, renewal, cancellation, and benefit copy before purchase.

#### Step 5.2 — Implement the StoreKit 2 transaction layer

- [ ] Load products and eligibility.
- [ ] Prevent duplicate purchase attempts while a transaction is pending.
- [ ] Verify transactions before granting client access.
- [ ] Send signed transaction evidence to the trusted backend for server entitlement reconciliation.
- [ ] Listen for transaction updates through the application lifecycle.
- [ ] Implement restore purchases and manage subscription.

#### Step 5.3 — Implement every entitlement state

- [ ] Free, trial, active monthly, active annual, grace/billing retry, pending, canceled-but-active, expired, revoked/refunded, verification failure, offline/stale, and backend-mismatch.
- [ ] Keep last safe access only according to the approved entitlement policy; never upgrade on an unverified transaction.
- [ ] Reconcile reinstall, device change, account change, family-sharing policy, refund, and expiry.
- [ ] Ensure Pro never changes score, mastery, XP, or social standing (`LAW-13`).

#### Step 5.4 — Connect honest product benefits

- [ ] Show the free counter before the limit and the paywall only after learning value.
- [ ] Resume the interrupted fourth-lesson start after verified purchase.
- [ ] Unlock unlimited new starts and allowed AI revisions/follow-ups within abuse limits.
- [ ] Unlock eligible program downloads/offline starts.
- [ ] Unlock capstone submission; do not imply accredited certificates.

**Exit — Phase 6 complete:** The full StoreKit sandbox matrix, backend reconciliation, restore, upgrade, pending, cancellation, billing retry, refund, expiry, reinstall, and offline/stale cases pass with no entitlement bypass or duplicate purchase.

---

### Stage 6 — Build bounded 1.0 social (Phase 7)

**Outcome:** Learners can connect and react without open discovery, ranking pressure, or free-text abuse surfaces.

#### Step 6.1 — Implement privacy-safe profiles and discovery

- [ ] Make social opt-in.
- [ ] Default teen profiles to stricter privacy.
- [ ] Support exact handle lookup and explicit invite only; do not add broad people discovery.
- [ ] Expose only the Product Bible-approved public profile fields.
- [ ] Add friend request send, receive, accept, decline, cancel, and remove states.

#### Step 6.2 — Implement preset interactions

- [ ] Allow approved preset reactions only.
- [ ] Add accessible reaction status and removal.
- [ ] Do not ship DMs, comments, free-text social, leagues, leaderboards, shared streaks, or team quests.
- [ ] Ensure subscriptions do not buy social rank.

#### Step 6.3 — Implement safety controls

- [ ] Add report with approved categories and trusted backend intake.
- [ ] Add block/unblock and prevent future visibility/interactions as specified.
- [ ] Remove blocked/reported content from local caches immediately where required.
- [ ] Test race conditions, offline caches, repeated requests, enumeration resistance, and unauthorized profile reads/writes.
- [ ] Document moderation/support response ownership.

**Exit — `GATE-TF-CLOSED`:** Phases 5–7 pass; StoreKit sandbox passes; critical accessibility passes on device; privacy policy, terms, and support are live; retention baselines are recorded; and there are zero open critical security, safety, purchase, or data-loss defects.

---

### Stage 7 — Complete profile, content, and operations (Phase 8)

**Outcome:** The complete 1.0 product is controllable by the learner and observable by the launch team.

#### Step 7.1 — Build Profile and Settings

- [ ] Account/profile and age-segment-safe public profile controls.
- [ ] Learning preferences, experience, selected path, coach mode, and daily goal.
- [ ] Notification preferences, requested only after the first result and never blocking learning.
- [ ] Membership status, restore, and manage subscription.
- [ ] Download management and storage state.
- [ ] Privacy, safety, blocked users, help, support, policies, app/version information, sign-out.

#### Step 7.2 — Implement trusted data rights workflows

- [ ] In-app account deletion request with reauthentication and clear consequences.
- [ ] Trusted backend deletion propagation across auth, product data, derived records, vendor data, and scheduled backups according to policy.
- [ ] In-app data export request, status, secure delivery, expiry, and audit trail.
- [ ] Test partial failure, retry, duplicate request, revoked session, and support escalation.

#### Step 7.3 — Complete production services and observability

- [ ] Production Firebase Auth, Firestore, Functions, Storage, App Check, Remote Config, Messaging, Analytics, and Crashlytics configuration.
- [ ] Least-privilege Security Rules and backend authorization tests for every protected collection/function.
- [ ] Structured logs, dashboards, alerts, trace/correlation IDs, rate limits, cost controls, and runbooks.
- [ ] Validate the complete Book VI event taxonomy and `LAW-19` payload restrictions.
- [ ] Add safe client defaults for unavailable Remote Config.

#### Step 7.4 — Load and editorially certify launch content

- [ ] AI Foundations: at least 3 modules, 12 lessons, and 1 applied capstone.
- [ ] Chosen specialization: at least 2 modules and 8 real lessons.
- [ ] Remaining three specialization shells: honest title, promise, and “more modules arriving” records with no fake lessons.
- [ ] Validate every objective, rubric, asset, caption/transcript, completion rule, prerequisite, duration, accessibility description, and version link.
- [ ] Run editorial, instructional, safety, copyright/license, and accessibility QA on every published 1.0 lesson version.

#### Step 7.5 — Test production-scale and failure behavior

- [ ] Load-test lesson starts/completions, progress reconciliation, AI bursts, subscription reconciliation, and export/deletion queues.
- [ ] Drill provider outage, AI timeout, Firebase degradation, auth expiry, stale cache, duplicate delivery, and rollback.
- [ ] Confirm no expected failure erases learner work.
- [ ] Track crash-free sessions toward 99.8% and visible AI failure below 2%, or approve a documented remediation plan.

**Exit — `GATE-TF-EXPANDED`:** Editorial QA covers every launch lesson; notifications, downloads, deletion, and export work end to end; load evidence exists; no P0/P1 crash, data-loss, purchase, or safety defect is open; crash-free reliability approaches 99.8%.

---

### Stage 8 — Certify and submit the release (Phase 9)

**Outcome:** A signed, monitored, reviewable 1.0 build is accepted for App Store submission.

#### Step 8.1 — Finish the app identity and required metadata

- [ ] Final app icon and asset catalog.
- [ ] Launch appearance, display name, category, age rating, copyright, version/build scheme.
- [ ] Privacy manifest and required-reason API declarations.
- [ ] App Privacy labels matched to the implemented data flows and vendors.
- [ ] Localized subscription disclosures, privacy URL, terms URL, support URL, and marketing copy.
- [ ] App Store screenshots and preview assets that show only shipping features.

#### Step 8.2 — Run the release device and accessibility matrix

- [ ] Minimum iOS 17 and current iOS.
- [ ] Representative smallest and largest supported iPhones.
- [ ] Physical-device VoiceOver flow for onboarding, lesson, feedback, paywall, purchase/restore, social safety, settings, deletion, and support.
- [ ] Dynamic Type through accessibility sizes, Switch Control, Reduce Motion, contrast, keyboard/focus where relevant, orientation policy, target sizes, captions/transcripts, and non-color status.
- [ ] Resolve every critical accessibility defect and record named sign-off.

#### Step 8.3 — Run the final functional matrix

- [ ] Fresh install, upgrade from supported previous build, kill/relaunch, reinstall, logout/login, account switch, and second device.
- [ ] Online, slow, intermittent, offline, stale cache, server timeout, auth expiry, and provider outage.
- [ ] All live auth providers.
- [ ] All StoreKit sandbox purchase and entitlement states.
- [ ] Free allowance boundary, midnight/learner-day reconciliation, revision/follow-up caps, downloads, progress, and duplicate requests.
- [ ] Social report/block cache behavior, deletion, export, notification opt-in/out, and support.
- [ ] Security/privacy review proves no production secret, debug endpoint, sensitive log, or unrestricted protected write ships.

#### Step 8.4 — Prepare App Review and launch operations

- [ ] Reviewer demo account and stable review data.
- [ ] Review notes explaining first lesson, AI identity/behavior, subscriptions, restore/manage, social safety, and account deletion.
- [ ] App Review can reach purchase and account management without hidden instructions.
- [ ] Production dashboards and alerts are active before release.
- [ ] Name release commander, incident/support contacts, content rollback owner, backend rollback owner, and app-release rollback owner.
- [ ] Freeze app and content versions; retain a tested rollback path.
- [ ] Define launch-day monitoring, escalation thresholds, status communication, and hotfix process.

#### Step 8.5 — Sign off and submit

- [ ] Canonical automated gate passes on the release commit with zero unexpected skips.
- [ ] TestFlight observation policy is satisfied.
- [ ] Crash-free sessions are at least 99.8% at submission.
- [ ] Visible AI failure is below the approved threshold.
- [ ] No P0/P1 security, safety, data-loss, purchase, accessibility, or crash defect is open.
- [ ] Product, curriculum, engineering, privacy, accessibility, support, and release owners sign the dated evidence.
- [ ] Upload the signed release candidate and submit it with the approved metadata.

**Exit — `GATE-STORE`:** Privacy labels, deletion, subscription disclosures, reviewer account, review notes, monitoring, and rollback ownership are complete; reliability meets target; App Review can use the core product, purchase, restore, manage an account, and delete it.

## 5. Gate evidence required

Create one dated evidence report per gate. Each report must link reproducible test results, screenshots or recordings where appropriate, backend/rules evidence, known-defect status, and named approvals.

| Gate | Minimum evidence |
| --- | --- |
| `GATE-ALPHA` | Phases 0–4 traceability; real lesson video/capture; online/offline/relaunch tests; AI schema and tone invariance suite; Rules denial; privacy threat model; zero progress-loss/duplicate-reward defects |
| `GATE-TF-CLOSED` | Phases 5–7; StoreKit matrix; device accessibility report; live privacy/terms/support; retention decision; security/safety/purchase/data-loss defect report |
| `GATE-TF-EXPANDED` | Phase 8; every lesson’s editorial QA record; deletion/export/download/notification evidence; load and failure drills; reliability and AI-failure dashboard |
| `GATE-STORE` | Phase 9 device matrix; signed-build gate; privacy manifest/labels; App Store assets; review account/notes; monitoring and rollback runbook; final cross-functional approvals |

## 6. Launch content and scope checklist

### Must ship

- [ ] Shared AI Foundations with 3 modules, 12 lessons, and 1 capstone.
- [ ] One chosen specialization with 2 modules and 8 real lessons.
- [ ] Three honest specialization shells.
- [ ] All required lesson formats and explainable AI feedback.
- [ ] Three free newly started lessons per learner-day, one free AI revision, and three free follow-ups per scored attempt.
- [ ] StoreKit 2 Pro, bounded social, settings, downloads, deletion, export, analytics, support, and release operations.

### Must not expand into 1.0 unless the Product Bible is amended

- [ ] No leagues or leaderboards.
- [ ] No team quests or shared streaks.
- [ ] No free-text social, comments, or direct messages.
- [ ] No complete depth for all five paths.
- [ ] No accredited certificate claim.
- [ ] No Android, learner web app, or required iPad optimization.
- [ ] No visual rewrite that delays the functional learner loop.

## 7. Immediate next work package

Start with this exact package and do not add AI, StoreKit, or social to it:

1. Resolve the deep-specialization owner decision; use AI for School if approved.
2. Configure development/staging Firebase access needed for the content platform.
3. Author the Phase 2 curriculum-platform implementation plan.
4. Implement the immutable content/rubric schema and publication validation.
5. Publish one Foundations fixture lesson through the private operator path.
6. Sync and render it read-only from the existing first-lesson handoff.
7. Prove online, cached, stale, incompatible-version, unauthorized-write, publish, and rollback behavior with tests.
8. Record the Phase 2 checkpoint evidence before beginning the full learning engine.

That checkpoint turns the current onboarding demonstration into the first real vertical slice and establishes the content identity required by attempts, scoring, offline recovery, AI rubrics, progress, and analytics.

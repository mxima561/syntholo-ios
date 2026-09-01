# Syntholo Phase 1 daily-goal and learning-settings completion plan

**Created:** August 30, 2026

**Status:** Product contract required before implementation; no daily-goal values, encoded identifiers, learner copy, or analytics event have been inferred

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Parent plan:** `docs/superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md`, Step 0.3

## 1. Outcome

Close the remaining local Phase 1 product gap using the onboarding behavior Product approves. If Product chooses the Bible's permitted default-and-edit-later path, every newly created learner profile receives the approved default without changing the accepted Book III onboarding route. If Product requires an explicit choice, that route and its tests must be amended before implementation. In either path, a signed-in learner can edit the preference under **Profile → Learning settings**; a failed save retains the attempted change, exposes retry, and survives relaunch. This slice does not require live Firebase credentials, gated curriculum, a specialization decision, or an analytics taxonomy expansion.

The Product Bible requires a daily goal under `SHIP-ONBOARD`, permits but does not mandate defaulting it and editing it later in Settings, requires learning settings under `SHIP-PROFILE`, and keeps Remote Config experimentation optional. It does not define what the goal measures, which values are valid, or which allowed onboarding path Product chooses. The three-free-lesson allowance is an entitlement limit, not an implied personal goal.

## 2. Product decision gate

Product must record and date this complete contract before a domain enum, learner copy, Firestore allowlist, or migration is authored:

| Required decision | Product-owned value |
| --- | --- |
| Measure | Minutes, lessons, sessions, or another exact unit |
| Selectable values | Ordered choices plus stable encoded identifiers |
| Default and fallback | Exact local fallback; valid/missing/invalid Remote Config behavior |
| Default source and assignment stability | Local-only, or the exact Remote Config key/value type, fetch/activate/cache/timeout policy, and assignment point. An assigned or persisted value is sticky; a late activation must not silently rewrite it |
| Achievement semantics | Exact qualifying activity/completion events and counting rules; do not reuse allowance, streak, or daily-challenge semantics implicitly |
| Reset and effective time | Any daily reset uses the frozen DEC-9 learner-day. Decide whether achievement accumulation is in scope and whether an edit applies to the current or next learner-day |
| Product use | Whether the goal affects Today, recommendations, reminders, progress display, or only learner preference copy in this slice. Any reminder use remains optional, independently controllable, and post-first-lesson under LAW-5 and `SHIP-ONBOARD` |
| Relationship to free allowance | Whether a personal goal may exceed the three-new-lesson free allowance; the goal itself must never grant or deny credits |
| Onboarding behavior | Apply the default silently and edit later while preserving the Book III route, or amend that route to add an explicit choice |
| Existing-profile migration | Exact behavior when a schema-1 preferences document has no daily-goal field |
| Learner-facing copy | Approved labels/descriptions/accessibility wording, or explicit authorization for engineering to author that copy for Product review |
| Approval record | Product owner, approval date, and Product Bible change reference |

Until all rows are resolved, engineering may maintain the plan and test harness but must not invent values, semantics, copy, persistence identifiers, or Remote Config keys. Book VI currently defines no daily-goal event, so this slice emits none. Any telemetry expansion is a separate Product Bible amendment and privacy review, not a blocker to the no-event implementation.

## 3. Fixed engineering boundaries

- Daily goal is a learner preference. It does not enforce allowance, completion, XP, streak, entitlement, or paywall behavior.
- Any daily reset uses DEC-9: local calendar date reconciled against server time. This plan does not reopen that frozen decision.
- Only the Product-approved achievement/reset/use semantics may make the goal influence Today, recommendations, reminders, or progress copy.
- Goal-driven reminders, if approved, remain opt-in, independently controllable, and may be prompted only after the first lesson under LAW-5 and `SHIP-ONBOARD`.
- Keep the accepted Book III onboarding route unchanged when Product chooses the Bible's allowed default-and-edit-later path.
- Do not reuse `goal_selected`, `duration_bucket`, or another existing analytics field.
- Keep email, profile text, and other private fields out of analytics.
- Persist only approved stable values and fail closed on unknown values after applying the approved legacy migration.
- Use a narrow daily-goal preference update. Do not rewrite the five-document aggregate profile from a stale Settings screen.
- Retain a UID-scoped pending edit locally before the network write; clear it only after acknowledgement.
- Keep Profile subnavigation local to the Profile tab. `AppRouter` remains responsible for primary-tab selection and the Learn path.
- All learner copy lives in `Localizable.xcstrings`; all controls use stable nonlocalized accessibility identifiers.
- Support iOS 17 with native SwiftUI and Observation APIs. No iOS 18-only navigation or tab API may be required.

## 4. Test-first implementation order after approval

### Task 1 — Freeze the approved domain/default contract

- Create `Syntholo/Services/Profile/DailyGoal.swift` with only the approved stable values.
- Add `LocalizedStringResource` title/detail properties for each value.
- Add a credential-free `DailyGoalDefaultProvider` whose local fallback is the approved value. If launch is local-only, inject no Remote Config dependency. If Product approves Remote Config, add the exact typed adapter and root composition for the approved key, fetch/activate/cache/timeout policy, and assignment point.
- Resolve the default once for a not-yet-created profile. For a Remote Config assignment, persist the assigned stable value in a separate versioned, UID-scoped `DailyGoalOnboardingAssignmentRepository` after authentication and before profile creation so save failure/relaunch cannot reassign it. Do not change the existing onboarding-draft envelope. Clear the assignment only after the profile-save acknowledgement; ignore another account's record. Late fetch or activation affects only learners without an assignment or persisted preference.
- Write focused tests for exact raw values, selectable order, approved local fallback, assignment persistence, valid override, missing/invalid/late configuration, the approved fetch-failure behavior, UID isolation, save-failure retention, post-ack clearing, and proof that assignment corruption/migration never clears an in-progress onboarding draft.

### Task 2 — Add backward-compatible profile persistence

- Add a nonoptional daily goal to `LearnerProfile` and new-profile creation.
- Keep `OnboardingDraft` and its saved envelope unchanged unless Product explicitly chooses a new onboarding screen. If Remote Config supplies the default, use only the separate UID-scoped assignment repository from Task 1; local-only default-and-edit-later needs no draft migration.
- Version the preferences shape independently from the unchanged private-user document: legacy preferences remain schema 1; the daily-goal shape is schema 2 and adds the approved value plus an integer `settingsRevision`.
- Add an explicit `ProfilePreferencesVersion` and loaded-profile snapshot so `ProfileRepository.save` returns, and `load` exposes, the learner profile plus the independent preferences schema and base revision. Do not overload `LearnerProfile.schemaVersion`, which remains the private-user schema.
- Freeze the version tokens: an exact schema-1 preferences document loads as synthetic `(schema: 1, revision: 0)` without a read-side rewrite; a newly created schema-2 document stores revision `0`; a successful v1→v2 migration or v2 update stores schema 2 and increments exactly once. Revisions are nonnegative signed 64-bit integers; missing, negative, nonincrementing, or overflowed values fail closed.
- Extend the decoder to accept user schema 1 with preferences schema 1 or 2. Unknown schema-2 goal values fail closed.
- Add a narrow transactional `ProfileRepository.updateDailyGoal` operation that takes the complete expected preferences-version token and returns a canonical acknowledgement containing the stored goal and new token. It changes only daily goal, revision, schema version during migration, and server `updatedAt`.
- Add a dedicated compare-and-set/transaction store seam used by the repository, with Firestore, in-memory recording, DEBUG UI-test, and unavailable implementations. The Firestore implementation performs the read and conditional write in one transaction; Swift contract tests prove retry and conflict mapping without bypassing the repository double.
- Recover a committed-but-lost response idempotently: if remote state is already schema 2 with the desired goal and exactly the expected next revision, return that state as the acknowledgement without another write; otherwise a nonmatching token is a conflict.
- Stage Rules and client rollout explicitly: compatibility Rules accept legacy v1 and new v2 creates, permit only a closed v1→v2 daily-goal migration, forbid v2→v1 downgrade, and validate v2 revision increments; the compatible client then ships and migrates on the first acknowledged edit. Only after the minimum supported client/data audit may final Rules stop accepting new v1 creates while retaining narrowly bounded migration for remaining v1 records.
- Because Syntholo is prelaunch, the final prelaunch deployment may move directly to v2 only after emulator tests prove legacy v1 load/migration and mixed old/new-client behavior. An old client encountering v2 must fail closed rather than overwrite it.
- Prove initial save/load with revision 0, legacy synthetic revision 0, v1→v2 revision 1, exact subsequent increments, overflow denial, v2 downgrade denial, mixed-client behavior, unknown-value rejection, revision conflict, and preservation of age, identity, path, coach, enrollment, handle, discoverability, and `createdAt`.

### Task 3 — Preserve pending changes through failure and relaunch

- Create a versioned, UID-keyed `ProfileSettingsDraftRepository` for the attempted daily goal.
- Persist the desired goal, complete base preferences-version token, UID, and local generation before any network write. A pre-write local-draft save failure blocks the network operation and exposes local retry/discard.
- Create one root-owned `@MainActor @Observable ProfileStore` shared by onboarding restoration and Profile UI. `AppDependencies` constructs one profile repository and one store, injects both into `OnboardingCoordinator`, and passes the store through `RootView` to `ProfileHomeView`; unavailable and exact DEBUG UI-test compositions receive explicit safe implementations.
- Install both a newly saved profile and a restored profile in the store before any transition to signed-in UI. Never discard a successful profile load after a non-nil check.
- Serialize one update flight and disable goal-choice changes while saving or while a remote outcome is unresolved. Install the canonical acknowledged/base token before enabling another selection. Guard every completion by UID plus local generation so an account switch or late result cannot mutate another account.
- Before every retry, including restore, load and reconcile remote state: a matching remote goal with a newer token satisfies the pending edit; an unchanged exact base may retry; a divergent newer token becomes an explicit conflict and never overwrites the other device silently.
- After a remote acknowledgement, rewrite the local draft as an acknowledged marker containing the canonical token, then clear it. Failure to save that marker and failure to clear it are distinct local-finalization states; their same-process recovery is local-only and never repeats the remote write. After relaunch from either failure, reconcile remote first.
- Model idle, saving, saved, pre-write-local-failure, remote-failure, conflict, post-ack-local-marker-save-failure, and post-ack-local-clear-failure separately.
- Test no network call after pre-write save failure; known remote failure; committed-then-response-failed reconciliation without a second write or false conflict; commit-before-clear crash recovery; marker-save and clear failures without a second remote write; relaunch reconciliation; divergent other-device revision; disabled B→C choice while B is in flight; duplicate taps; stale/late completion; and account isolation.

### Task 4 — Extend Firestore authorization narrowly

- Add the approved field and closed values to the exact preferences-document validation.
- Implement separate exact v1-legacy and v2-daily-goal validators and the staged rollout from Task 2; do not use a date check or treat two exact shapes as the same schema.
- Permit only the owner to create v2 at revision 0, migrate v1→v2 at revision 1, or increment a v2 revision by exactly one, with server `updatedAt`, without changing unrelated preferences.
- Deny missing/unknown/wrong-type values, cross-user writes, unknown keys, and attempts to change credits, XP, streak, subscriptions, or entitlements.
- Add emulator Rules tests before changing the rule allowlist.

### Task 5 — Replace the Profile placeholder with honest Settings UI

- Replace `ProfileHomeView` with a local `NavigationStack` and a typed route to `LearningSettingsView`.
- Show only implemented Profile capabilities; label all remaining areas as unavailable rather than presenting dead controls.
- Render the acknowledged and pending daily-goal states without relying on color alone.
- Use buttons or a native picker with at least 44-point hit regions, a clear selected trait/value, Dynamic Type-safe layout, deterministic focus order, accessible saving/locked feedback, and accessible retry/discard actions.
- Keep view-owned transient state private; the root-owned `ProfileStore` remains the persistence source of truth.

### Task 6 — Prove composition, UI, accessibility, and release separation

- Add exact DEBUG fixtures for success, fail-once/retry, pending-edit relaunch, and stored-value restore without constructing Firebase in `--ui-testing` composition.
- Add functional journeys for default display, save/reopen, failure/retry, and relaunch restore.
- Expand the seven Profile accessibility lanes to cover both Profile and Learning settings while preserving isolated canonical execution.
- Scan the String Catalog, DEBUG markers, Release bundle, full Git history, and worktree.
- Run focused domain/store/repository tests, Firestore Rules, the complete unit/UI/accessibility targets, environment/Release checks, and one uninterrupted canonical gate.
- Record exact discovered counts only after the final run; the current canonical local baseline remains 487 until this slice is implemented and verified.

## 5. Definition of done

- The dated Product decision is tracked and matches every raw value, default, migration, and learner-facing choice.
- New and legacy profiles resolve one valid daily goal plus an explicit preferences-version token without losing an in-progress onboarding draft or sticky Remote Config assignment.
- Settings changes only the intended preference and never overwrites concurrent profile fields.
- Failure and relaunch preserve the pending choice with retry/discard.
- Owner-only Rules tests pass and server-owned learning/economic fields remain immutable to the client.
- Profile and Learning settings pass deterministic functional and automated accessibility coverage on current iOS.
- Minimum-iOS 17 CI and named physical accessibility evidence remain separate Phase 1 exit requirements.
- No new analytics event is emitted unless Book VI is explicitly amended.

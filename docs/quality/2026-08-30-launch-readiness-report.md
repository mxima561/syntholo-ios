# Syntholo iOS launch-readiness report

**Audit date:** August 30, 2026  
**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`  
**Audit scope:** Repository, Product Bible alignment, canonical automated gate, current simulator flow, UX/accessibility risk, SwiftUI implementation quality, and launch delivery plan.

## Product goal

Ship Syntholo 1.0 as a trustworthy, accessible, native iPhone school for practical AI skills where a learner aged 13+ can complete the full Book III first-session and daily-learning loops, retain progress safely across interruption and connectivity changes, understand why work was scored, reach an honest free limit, purchase or restore Pro, use bounded social features safely, control or delete their data, and pass every Product Bible release gate through `GATE-STORE`.

This goal is intentionally narrower than the Book II north star. Launch does **not** require leagues, leaderboards, team quests, shared streaks, full five-path depth, free-text social, an accredited certificate system, Android, iPad optimization, or a web learner app.

## Executive verdict

Syntholo has a high-quality, freshly verified Phase 0 foundation and a substantially complete Phase 1 identity/onboarding slice. The current app is **not an internal alpha yet** because the learning product begins after the point where implementation stops.

The repository is healthy enough to build on: the complete canonical test gate passes, the implemented onboarding is visually coherent, and the SwiftUI baseline is modern and generally correct. The next move is not a visual rewrite. It is to build the missing content platform and learning engine behind the existing first-lesson handoff.

No Product Bible milestone is currently satisfied:

- `GATE-ALPHA` requires Phases 0–4 and a working onboarding → lesson → coach → sync → offline-recovery loop.
- `GATE-TF-CLOSED` requires engagement, subscriptions, bounded social, critical accessibility, and legal/support foundations.
- `GATE-TF-EXPANDED` requires operations, deletion/export, downloads, load evidence, and editorial QA.
- `GATE-STORE` requires release operations, privacy/App Review assets, account management, monitoring, and launch-quality reliability.

## Fresh verification evidence

The canonical `./scripts/test.sh` gate passed on this machine using Xcode 26.6, iPhone 17 Pro / iOS 26.5, XcodeGen 2.46.0, Node 22.23.2, npm 10.9.8, Java 21.0.12.1, Firebase CLI 15.28.1, and Firestore emulator 1.22.0.

| Gate | Fresh result |
| --- | ---: |
| Swift unit tests | 98 passed, 0 failed, 0 skipped |
| Functional UI journeys | 16 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 10 passed, 0 failed, 0 skipped |
| Firestore Rules | 20 passed, 0 failed, 0 cancelled, 0 skipped |

The recurring `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version` output is the repository's already-documented Xcode UI-test warning. It did not fail or skip tests.

`npm ci` reported five moderate vulnerabilities in development tooling dependencies. They are not shipped in the iOS app, but must remain on the dependency-review ledger. Do not use the suggested forced downgrade without a separate compatibility review.

## Current standing against the Product Bible

| Phase | Standing | What is real now | What blocks exit |
| --- | --- | --- | --- |
| 0 — Foundation | Verified | Swift 6, iOS 17, iPhone-only, XcodeGen, environments, design system, four tabs, CI/test gate | Physical-device checks still matter at release, but Phase 0 engineering is sound |
| 1 — Identity/onboarding | Substantially complete | Age gate, teen/adult distinction, goal, experience, editable path recommendation, five coach modes, Apple/Google/email architecture, profile persistence and recovery | Live provider smoke tests, production Firebase configuration, physical VoiceOver evidence, daily-goal/settings completion |
| 2 — Curriculum platform | Missing | Foundation/path IDs are only stored in preferences | Versioned programs/modules/lessons/rubrics, sync, publish, rollback, private operator path, chosen deep specialization |
| 3 — Learning engine | Missing | First-lesson handoff is only a seam | Player, required formats, deterministic scoring, attempts, start limits, durable queue, cache/offline recovery, progress semantics |
| 4 — AI coach | Missing | Coach-mode preference only | Moderation, immutable rubric load, structured scoring, server validation, separate tone rendering, feedback/revision/follow-up, fail-soft recovery |
| 5 — Engagement | Missing | Learn and Practice placeholders | Today mission, next action, XP, streak, daily challenge, objective review, persistence/reconciliation |
| 6 — Subscriptions | Missing | No StoreKit code or configuration | Products, localized prices, trial/renewal/cancel copy, entitlement verification, updates, pending/refund/billing states, restore/manage |
| 7 — 1.0 social | Missing | Social placeholder; hidden profile primitives exist | Opt-in friends, exact lookup/invite, requests, preset reactions, report, block, cached-removal behavior |
| 8 — Profile/operations | Missing | Profile placeholder | Settings, notifications, membership, downloads, privacy/safety, support, export, deletion, complete analytics/telemetry |
| 9 — Store hardening | Not started | CI and accessibility harness provide a strong base | App icon, privacy manifest/labels, screenshots, review assets/account, release monitoring/rollback, reliability targets, final device matrix |

## Combined UX and accessibility audit

### User goal and accessibility target

The audited user is a new adult learner choosing AI for School with beginner experience and the Supportive coach. The target is a clear, low-friction path from eligibility confirmation to a real first Foundations lesson, usable with VoiceOver, Dynamic Type, non-color state communication, and minimum 44-point targets.

### Step 1 — Welcome: healthy

![Welcome](screenshots/01-welcome.png)

The visual direction is original and appropriate for a school: editorial serif headline, academic ink, restrained diagram language, and one obvious action. The promise centers judgment rather than tricks, aligning with LAW-1. The screen is spacious without hiding the CTA.

Risk: “before your first lesson” creates a near-term promise the current build cannot fulfill.

### Step 2 — Age confirmation: healthy

![Age confirmation](screenshots/02-age.png)

Eligibility is explicit, under-13 is not disguised, and no birth date is requested. Teen and adult choices have large targets and readable descriptions. This is strong SHIP-AGE / LAW-15 behavior.

Risk: both allowed choices use identical descriptions, so the visible reason for distinguishing teen from adult is not explained. Keep privacy details concise, but later privacy settings should make the stricter teen defaults transparent.

### Step 3 — Goal selection: healthy

![Goal selection](screenshots/03-goal.png)

The four goals map cleanly to the Product Bible paths. Labels are plain, the examples clarify scope, and the information density remains manageable.

Risk: every row advances immediately. This is efficient, but VoiceOver focus movement after selection still needs physical-device verification.

### Step 4 — Experience selection: healthy

![Experience selection](screenshots/04-experience.png)

Experience is correctly framed as pace/explanation level rather than coach personality. This preserves DEC-7 and avoids implying that advanced learners are graded differently.

### Step 5 — Path recommendation: healthy with a terminology issue

![Path recommendation](screenshots/05-path.png)

Foundations-first sequencing is prominent, the recommendation is editable, and the route graphic is meaningfully labeled for assistive technology. The hierarchy makes the primary recommendation easy to accept without hiding alternatives.

Risk: this screen drops the numbered “Orientation” convention and uses “Your route.” That may be intentional, but the progress model becomes less predictable. The complete flow visually contains more than six meaningful screens once the handoff is included.

### Step 6 — Coach selection: healthy

![Coach selection](screenshots/06-coach.png)

All five modes are visible, Supportive defaults correctly, and selection uses border, checkmark, accessibility selected trait/value, and color together. The copy clearly states that tone does not change grading, supporting LAW-3.

### Step 7 — Account creation: healthy at fixture level

![Account creation](screenshots/07-account.png)

Apple, Google, and email are given comparable prominence and Apple remains present beside third-party login. The screen arrives after learner value/preferences have been established and before progress sync, aligning with SHIP-AUTH and SHIP-FIRST-LESSON ordering.

Limit: this audit used the repository's non-secret authentication fixture. Live Apple, Google, and email provider behavior was not verified.

### Step 8 — First-lesson handoff: visually healthy, functionally critical

![First-lesson handoff](screenshots/08-first-lesson-handoff.png)

The handoff is specific and motivating: named program, lesson number, concrete skill, and one action. Visually, this is the right bridge into the product.

Critical defect: the CTA promises “Start the first lesson,” but no lesson is started.

### Step 9 — Actual destination: blocked product loop

![Learn placeholder](screenshots/09-learn-placeholder.png)

The action lands on a placeholder campus screen saying the lesson and progress “will appear here.” This is direct evidence that SHIP-FIRST-LESSON and the Book III new-learner loop are not implemented. It is the highest-priority product gap because it breaks the exact moment where onboarding must convert into learning value.

The tab shell itself is visually clean and readable, but Practice, Social, and Profile are also placeholders in source.

## SwiftUI Expert assessment

### Strong implementation choices

- The project uses iOS 17-era Observation correctly: `@Observable`, view-owned observable state through `@State`, and injected bindable models through `@Bindable`.
- `NavigationStack`, native `Button`, native sheet presentation, semantic SwiftUI colors, system text styles, and SF Symbols form a solid accessible baseline.
- Interactive rows use stable model identity rather than array offsets.
- `@FocusState` is private and used for the email form.
- Controls expose selected traits/values and decorative symbols are hidden where appropriate.
- No old `NavigationView`, `navigationBarItems`, generic accessibility API, or gesture-only button substitute was found.
- The current `.tabItem` implementation is appropriate for an iOS 17 deployment target. The newer `Tab` API cannot replace it unconditionally without raising the minimum OS or adding availability branches.

### SwiftUI and reliability improvements

1. **Do not silently discard onboarding-draft persistence errors.** `OnboardingStore` uses `try?` for save/clear operations. The UI then says choices are safe on the device even when persistence may have failed. Introduce a typed recoverable persistence state and test it before expanding the learning queue. This is an early version of LAW-11.
2. **Replace runtime localization conversion for enum copy.** Path and choice models carry `String`/`LocalizedStringKey` mixtures and sometimes construct `LocalizedStringKey` from runtime strings. The current catalog happens to contain those values, but extraction is brittle. Model fixed user-facing enum copy as `LocalizedStringResource` and pass it directly to SwiftUI.
3. **Remove runtime `.textCase(.uppercase)` for localizable headings.** Put the intended casing in the catalog so translators control it.
4. **Keep state ownership private where possible.** Current local `@State` properties are private, which is good. Continue that rule in new lesson/player views.
5. **Do not adopt iOS 26-only visual APIs for launch.** The minimum remains iOS 17. Any future iOS 26 polish must be availability-gated with an iOS 17 fallback and must not fork the product's core interaction model.
6. **Do not over-centralize the future player in one observable object.** Separate narrow observable state for content, current activity, attempt/sync status, and entitlement/allowance so unrelated network or queue changes do not invalidate the whole lesson tree.

## Launch definition of done

Syntholo 1.0 is launch-ready only when all of the following are true:

### Core learner loop

- A 13+ learner completes onboarding, creates an account, and starts a real Foundations lesson in the same session.
- The lesson contains instruction and an applied check, returns deterministic or rubric-grounded feedback, supports allowed revision, and records results.
- Today shows a real next action, streak, XP, and preview that survive kill/relaunch and another device where supported.
- Already-started cached work survives expected failures and can be completed offline under Book III rules.

### Curriculum and content

- Foundations contains at least 3 modules, 12 lessons, and one structured capstone.
- One explicitly chosen specialization contains at least 2 modules and 8 real lessons.
- The other three specializations are honest catalog records with promises and “more modules arriving,” not fake lessons.
- Published lesson/rubric versions are immutable and a private draft/publish/rollback path exists.

### Integrity, AI, and safety

- Attempts receive stable IDs before submission and all rewards/allowances/entitlements are server-authoritative and idempotent.
- AI evaluation uses moderation, immutable rubrics, structured scoring, server validation, and a separate tone renderer.
- Feedback names criteria/evidence, improvement, and one next action; AI identity is visible.
- Timeouts, invalid schemas, auth expiry, sync failure, and crashes preserve learner work.
- App Check protects supported production functions and no secret ships in the client.

### Monetization and social

- Free learners see their 3-start allowance before the limit, can resume without another credit, and see an honest paywall only after value.
- StoreKit 2 supports localized prices, annual trial disclosure, verified entitlements, transaction updates, restore/manage, and all pending/failure/refund/expiry states.
- Social is opt-in and limited to friends, exact lookup/invite, preset reactions, report, and block. No leagues or free-text social ship.

### Privacy, accessibility, and operations

- In-app account deletion and export request paths work end to end.
- Notification, coach, learning, membership, downloads, privacy/safety, and support controls exist.
- Core flows pass automated audits plus physical VoiceOver, Dynamic Type, Reduce Motion, Switch Control, contrast, and target-size checks on iOS 17 and current iOS.
- Retention periods, vendor data-use restrictions, privacy manifest/labels, age rating, terms, privacy policy, and support URLs are approved.
- Required analytics are stable and validated without raw answers, submissions, prompts, transcripts, email, or private profile text.

### Release operations

- App icon and all App Store assets exist.
- StoreKit sandbox and Firebase staging/production matrices pass.
- Crash-free sessions meet 99.8% at submission; monitoring, rollback owners, reviewer account, and review notes are ready.
- Every open P0/P1 security, safety, data-loss, purchase, accessibility, and crash defect is resolved.
- `GATE-ALPHA`, `GATE-TF-CLOSED`, `GATE-TF-EXPANDED`, and `GATE-STORE` each have dated evidence and named sign-off.

## Prioritized delivery roadmap

### Milestone 1 — Make Syntholo real: Phases 2–4

1. Choose the one deep specialization and freeze the versioned curriculum/rubric contract.
2. Build the constrained publisher with draft, publish, immutable version, and rollback.
3. Render a published fixture program/module/lesson in the iPhone app.
4. Build the lesson engine around stable attempt IDs, deterministic objective scoring, durable queue states, cache/resume, credit semantics, and interruption tests.
5. Connect the current first-lesson CTA directly to the real first lesson.
6. Add the split AI evaluation pipeline, recoverable failure states, feedback, one free revision, and three free follow-ups.
7. Exit only when the full `GATE-ALPHA` loop works online, through kill/relaunch, and through supported offline recovery.

### Milestone 2 — Closed TestFlight: Phases 5–7

1. Replace Learn/Practice placeholders with Today, next mission, XP/streak, review, daily challenge, and queue state.
2. Implement daily allowance and StoreKit entitlements together so neither client UI nor purchase state can bypass the server.
3. Build bounded social from the existing hidden-profile/handle foundations: friends, requests, preset reactions, report, and block.
4. Complete critical legal/support surfaces and physical accessibility testing.

### Milestone 3 — Expanded TestFlight: Phase 8

1. Build profile/settings, notification controls, downloads, membership management, privacy/safety, help, deletion, and export.
2. Load and editorially QA the complete 1.0 curriculum.
3. Complete analytics, Crashlytics/operational dashboards, load tests, retention policy implementation, and failure drills.

### Milestone 4 — App Store: Phase 9

1. Finish icon, privacy manifest, Store listing, subscription disclosures, screenshots, support/privacy URLs, review account, and review notes.
2. Run the oldest/current OS device matrix, StoreKit sandbox matrix, live provider matrix, offline/upgrade/reinstall tests, and physical accessibility sign-off.
3. Freeze app/content versions, assign monitoring and rollback owners, satisfy reliability targets, and record final sign-off.

## Immediate next implementation slice

Author the Phase 2 curriculum-platform plan against Book III and the current codebase. Its first vertical checkpoint should be:

> A privately published, immutable Foundations fixture containing a program, module, lesson version, objective, expected duration, completion rule, still-diagram/concept content, one deterministic question, and rubric/version references syncs into the app and renders read-only from the existing first-lesson handoff.

Do not add AI, StoreKit, leagues, or a broader redesign to that checkpoint. Prove content identity and immutability first; every later attempt, score, offline recovery, and reward depends on it.

## Evidence limits

- Simulator captures verify visible layout and navigation behavior for the audited fixture, not live provider/network behavior.
- Automated accessibility audits passed, but screenshots and XCTest do not prove spoken VoiceOver focus/announcements on physical hardware.
- Only iOS 26.5 ran locally. The configured iOS 17.5 CI job remains required for minimum-OS evidence.
- This folder currently lacks `.git` metadata, so commit provenance and a clean working-tree comparison could not be verified.

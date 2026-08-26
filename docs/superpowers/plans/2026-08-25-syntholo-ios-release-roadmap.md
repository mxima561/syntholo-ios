# Syntholo iOS MVP Release Roadmap

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the approved Syntholo iPhone MVP to the App Store through quality-gated, independently reviewable engineering slices.

**Architecture:** A native SwiftUI client uses Firebase for identity, synchronized product data, remote configuration, messaging, analytics, crash reporting, and server functions. StoreKit 2 owns subscription transactions and entitlements. All OpenAI traffic passes through authenticated server code. Versioned curriculum content is published through a private admin portal and rendered from a stable client-side schema.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing/XCTest, XcodeGen, Firebase Apple SDK, Cloud Functions for Firebase, TypeScript, OpenAI Responses API, StoreKit 2, GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-08-25-syntholo-ios-mvp-prd.md`

## Global Constraints

- Minimum deployment target: iOS 17.0; iPhone only for MVP.
- Product bundle identifier: `com.syntholo.ios`; signing may override the team identifier without changing source layout.
- English-only UI at launch, with all learner-facing strings stored in String Catalogs.
- The five coach modes are Supportive, Funny, Strict, Chill, and Socratic. Tone never changes grading standards.
- Free accounts receive three completed lessons per local calendar day, reconciled against server time.
- Pro pricing is $9.99 monthly or $69.99 annually; annual includes a seven-day trial.
- No OpenAI key, Firebase service credential, or App Store secret may ship in the app bundle or repository.
- Users aged 13–17 receive the same core curriculum with stricter privacy defaults and no free-text social communication.
- Each slice must pass unit tests, UI smoke tests, accessibility checks, analytics validation, and privacy review before merging.
- The approved PRD remains authoritative. Product-scope changes require a dated PRD amendment before implementation.

---

## Delivery Map

| Phase | Executable plan | Primary outcome | Depends on | Exit gate |
|---|---|---|---|---|
| 0 | `2026-08-25-syntholo-ios-foundation.md` | Reproducible project, design system, app shell, CI | Approved PRD | Clean build and test on iOS 17 simulator |
| 1 | `2026-08-25-syntholo-identity-onboarding.md` | Age gate, authentication, goals, path and coach selection | Phase 0 | New learner reaches Learn home with persisted profile |
| 2 | `2026-08-25-syntholo-curriculum-platform.md` | Versioned content schema, admin publishing, curriculum sync | Phases 0–1 | Published fixture course renders and updates safely |
| 3 | `2026-08-25-syntholo-learning-engine.md` | Lesson player, exercise types, progress, limits, offline queue | Phases 1–2 | A full module works online and through interruption/recovery |
| 4 | `2026-08-25-syntholo-ai-coach.md` | Five tone modes, rubric scoring, hints, revisions, safety | Phases 1–3 | Structured feedback is explainable, safe, and mode-consistent |
| 5 | `2026-08-25-syntholo-engagement.md` | Campus home, streaks, XP, daily challenge, review queue | Phases 2–4 | Engagement rewards learning without blocking recovery |
| 6 | `2026-08-25-syntholo-subscriptions.md` | StoreKit products, paywall, entitlements, restore, limits | Phases 1–5 | Sandbox purchase matrix and server reconciliation pass |
| 7 | `2026-08-25-syntholo-social.md` | Profiles, friends, leagues, reactions, shared streaks | Phases 1, 3, 5 | Abuse-resistant preset-only social flow passes safety review |
| 8 | `2026-08-25-syntholo-profile-operations.md` | Settings, downloads, notifications, privacy, support, analytics | Phases 1–7 | Account controls and operational telemetry are complete |
| 9 | `2026-08-25-syntholo-app-store-hardening.md` | Accessibility, privacy manifests, performance, TestFlight, release | All phases | Every PRD release gate and App Store checklist item passes |

## Dependency Flow

```text
Foundation
  └── Identity & onboarding
       ├── Curriculum platform ── Learning engine ── AI coach
       │                              └────────────── Engagement
       ├── Subscriptions ◀──────────────────────────────┘
       └── Social ◀──────────── Learning + Engagement

All product slices ── Profile & operations ── App Store hardening
```

## Release Milestones

### Milestone A — Internal Alpha

- [ ] Complete phases 0–4.
- [ ] Publish AI Foundations sample content through the admin path.
- [ ] Verify onboarding, one complete lesson, coach feedback, progress sync, and offline recovery.
- [ ] Run privacy threat model for minors, AI requests, and stored learner work.
- [ ] Confirm crash-free launch and deterministic analytics in development and staging.

### Milestone B — Closed TestFlight

- [ ] Complete phases 5–7.
- [ ] Load all five path shells and enough approved content to test progression.
- [ ] Validate daily limits, purchase/restore/refund states, leagues, reactions, and shared streaks.
- [ ] Conduct VoiceOver, Dynamic Type, Reduce Motion, contrast, and keyboard-access reviews.
- [ ] Record retention, lesson completion, coach usefulness, and paywall funnel baselines.

### Milestone C — Expanded TestFlight

- [ ] Complete phase 8.
- [ ] Load the full launch curriculum and perform editorial QA on every published lesson version.
- [ ] Run notification, download, account deletion, data export, and support workflows.
- [ ] Complete load tests for synchronized lesson completion and AI evaluation bursts.
- [ ] Resolve all P0/P1 crashes, data-loss defects, purchase defects, and safety findings.

### Milestone D — App Store Submission

- [ ] Complete phase 9.
- [ ] Freeze the release candidate and content versions.
- [ ] Pass automated test suites on the oldest supported iPhone simulator and current iOS.
- [ ] Pass StoreKit sandbox matrix, Firebase rules tests, server integration tests, and offline recovery suite.
- [ ] Approve privacy labels, age rating, subscription disclosures, review notes, screenshots, and support URLs.
- [ ] Obtain final product, curriculum, engineering, privacy, and accessibility sign-off.

## Quality Gates Applied to Every Phase

- [ ] Requirements are traced to PRD sections and acceptance criteria.
- [ ] New behavior begins with a failing automated test where technically feasible.
- [ ] Error, empty, loading, offline, retry, and accessibility states are implemented with the happy path.
- [ ] Analytics events contain no lesson answer, learner submission, prompt, or sensitive profile text.
- [ ] Remote configuration has safe client defaults and cannot weaken safety or entitlement checks.
- [ ] Server-authoritative mutations are idempotent and protected by Firebase Security Rules/App Check.
- [ ] User-facing strings are localizable and UI remains usable at accessibility text sizes.
- [ ] No release advances with known data loss, entitlement bypass, unsafe AI output path, or inaccessible critical flow.

## Plan Authoring Order

- [ ] Execute and verify the foundation plan.
- [ ] Author the identity/onboarding and curriculum-platform plans against the resulting project interfaces.
- [ ] Author learning-engine and AI-coach plans after the content schema is proven with fixtures.
- [ ] Author engagement, subscriptions, and social plans after progress semantics are stable.
- [ ] Author operations and App Store hardening plans last so they reference the real integrated system.


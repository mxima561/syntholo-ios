# Syntholo Product Bible

**Status: Binding** source of truth  
**Date:** August 25, 2026  
**Product:** Syntholo for iPhone  
**Audience:** Founder, engineering, curriculum, privacy, and any agentic worker implementing Syntholo  
**Supersedes:** `docs/superpowers/specs/2026-08-25-syntholo-ios-mvp-prd.md` where the two conflict  
**Plans implement this bible; they do not outrank it.**

---

## 0. How to use this document

This is the product and engineering constitution. If a plan, a prompt, a ticket, or a model’s improvisation disagrees with this file, this file wins.

### 0.1 Document map

| Artifact | Role | May change product scope? |
| --- | --- | --- |
| **This bible** | Law. Product identity, first-ship contract, north-star, engineering constraints, gates | Only via dated amendment (Book VIII) |
| Original PRD | Historical product draft. Useful detail. Not law where it conflicts | No |
| `docs/superpowers/plans/*-release-roadmap.md` | Delivery sequence | No. Sequence may be reordered only if dependencies in Book VII still hold |
| Slice plans (`*-foundation.md`, later slices) | How to implement one phase | No. A plan may not add screens, paths, social surfaces, or paywalls absent from Book III |

### 0.2 Citation

Cite by ID in code comments, PRs, and agent prompts:

- `LAW-*` — inviolable. Never ship a violation.
- `DEC-*` — frozen implementation decision.
- `SHIP-*` — required for App Store 1.0.
- `STAR-*` — north-star. Build the seam, not the feature, unless Book III also lists it.
- `GATE-*` — a release may not advance if this fails.

### 0.3 Two layers, one product

Syntholo has a complete destination (Book II) and a first ship (Book III).

Agents build **Book III**. They keep **Book II** from being painted into a corner. They do not implement Book II features “while they are in the area.”

### 0.4 What this bible is not

- Not an Xcode tutorial.
- Not a task checklist. Slice plans own checkboxes and sample code.
- Not a license to recreate another app’s layout, copy, or assets (including Mimo).

---

## Book I — Constitution

These laws apply to every phase, every environment, and every agent.

### Product laws

**LAW-1 Teach durable skill.** Lessons teach mental models, evaluation, limitations, and responsible use. Prompt tricks may appear as examples. They are never the learning objective.

**LAW-2 Learners act.** Every module contains instruction plus applied interaction. A video or article with no check or application is not a complete lesson.

**LAW-3 Rubrics are stable.** Coach tone, explanation level, and personality never change scores, pass/fail, or mastery. Scoring and tone are separate pipeline stages.

**LAW-4 Show why.** AI scores name rubric criteria and cite evidence from the learner’s work. A score without visible criteria is a defect.

**LAW-5 Respect attention.** No false urgency, fake scarcity, obstructed cancellation, misleading pricing, or pay-to-win. Session length is not a success metric. Notifications are optional and independently controllable.

**LAW-6 Protect trust.** Privacy, child-adjacent safety (13–17), accessibility, purchase clarity, and account deletion are release requirements, not polish.

**LAW-7 Remote change, local safety.** Curriculum, models, prompts, limits, and experiments may be configured remotely. Remote config **cannot** weaken entitlement checks, safety filters, age rules, or rubric integrity.

### Integrity laws

**LAW-8 Server is authoritative** for XP, mastery, lesson credits, streaks, league points, achievements, certificates, friendships, blocks, and subscription access. The client may cache and queue. It may not grant those rewards on its own.

**LAW-9 Exactly-once rewards.** Attempts use stable IDs and idempotency keys. Completing, retrying, or syncing the same attempt cannot grant XP, credits, or streak progress twice.

**LAW-10 Device clocks cannot cheat.** Daily credits and streaks use a server-defined day boundary. The client may display local time. Clock changes, time-zone spoofing, and offline date rolls cannot create credits or restore streaks.

**LAW-11 No expected failure erases learner work.** Timeouts, invalid AI schema, sync failure, auth expiry, and crashes must leave the response recoverable.

**LAW-12 Secrets never ship.** No OpenAI key, Firebase service credential, App Store secret, or admin token in the app bundle, client source, or git history.

**LAW-13 Purchases never buy rank.** Subscriptions may unlock volume, offline starts, projects, and certificates. They never alter XP, league scoring, mastery, or social rank.

**LAW-14 No free-text social.** Learners never send free-text DMs, comments, or public posts. Encouragement uses a curated preset reaction library. The AI coach may receive free-text **about the current lesson**; that is tutoring, not social, and it is moderated.

**LAW-15 No users under 13.** Age confirmation is required before account creation. There is no child mode, parental gate, or under-13 content in this product line.

**LAW-16 English UI at launch.** All learner-facing strings live in String Catalogs. Layout and content schema remain localization-ready. Do not hard-code copy in views except previews and tests.

### Agent laws

**LAW-17 Scope additions require an amendment.** If a task would add a path, screen family, social surface, certificate, or paywall not in Book III, stop and amend this bible first.

**LAW-18 Tests before behavior.** New behavior starts with a failing automated test where technically feasible. Error, empty, loading, offline, retry, and accessibility states ship with the happy path.

**LAW-19 Analytics never log answers.** Events must not contain lesson answers, learner submissions, prompts, raw coach transcripts, email, or private profile text.

**LAW-20 Do not copy other products.** System typography, semantic color, SF Symbols, and original editorial diagrams. No proprietary assets, layout clones, or copied lesson copy from other learning apps.

---

## Book I.A — Frozen decisions

These are closed. Do not re-litigate in a slice plan.

| ID | Decision | Value |
| --- | --- | --- |
| DEC-1 | Minimum iOS | **17.0** |
| DEC-2 | Devices | **iPhone only.** iPad may run iPhone compatibility mode. No iPad layout work in 1.0 |
| DEC-3 | Bundle ID | `com.syntholo.ios` |
| DEC-4 | Product name | Syntholo |
| DEC-5 | Language | English UI; String Catalogs required |
| DEC-6 | Coach modes | **Supportive, Funny, Strict, Chill, Socratic** (five). Tone never grades |
| DEC-7 | Explanation levels | Beginner-friendly, Intermediate, Advanced. These are not personalities |
| DEC-8 | Free daily limit | **3 completed newly-started lessons** per learner-day |
| DEC-9 | Learner-day | Local calendar date **reconciled against server time** (LAW-10) |
| DEC-10 | Pro monthly | $9.99 USD list; **always display StoreKit localized price** |
| DEC-11 | Pro annual | $69.99 USD list; **7-day free trial**; localized StoreKit price |
| DEC-12 | Subscription group | One auto-renewable StoreKit 2 group |
| DEC-13 | Auth | Sign in with Apple, Google, email/password |
| DEC-14 | Tabs | Learn, Practice, Social, Profile |
| DEC-15 | Age | 13+ only. 13–17 get stricter privacy defaults (SHIP-TEEN) |
| DEC-16 | AI provider | OpenAI Responses API, **server-only** |
| DEC-17 | Client stack | Swift 6, SwiftUI, Observation, `NavigationStack`, Swift concurrency |
| DEC-18 | Backend | Firebase Auth, Firestore, Storage, Cloud Functions, Messaging, Analytics, Crashlytics, App Check, Remote Config |
| DEC-19 | Project generation | XcodeGen; `Syntholo.xcodeproj` is generated and gitignored |
| DEC-20 | Environments | `development`, `staging`, `production` via xcconfig; unknown → development |
| DEC-21 | Hit targets | Minimum **44×44 pt**; primary actions use **48 pt** height |
| DEC-22 | Concurrency | `SWIFT_STRICT_CONCURRENCY = complete` |

---

## Book I.B — Problem, audience, non-goals

### Problem

People meet AI tools faster than they can build reliable skill. Existing education is passive, fragmented, overly technical, or built on isolated prompt tricks. Learners need a guided path from responsible everyday use to automation, coding, and building.

Without that path they repeat shallow tutorials, accept unreliable output, expose sensitive information, and never convert experimentation into capability.

### Audience

- Learners 13+ who are new to AI
- Students using AI for research, studying, writing, and organization
- Professionals using AI for research, communication, analysis, and workflows
- Creators using AI for ideation, production, and publishing
- Aspiring builders learning automation, coding, agents, and AI apps

**First ship does not serve all of these equally.** Book III ships shared Foundations plus **one** chosen specialization in depth. Other specializations exist as catalog shells so the north-star IA does not have to be rebuilt.

### Launch constraints

- English only
- iPhone only
- No under-13
- No organization, classroom, parent, or teacher administration

### Non-goals (do not build)

- Android, iPad-optimized, macOS, or web learner apps (backend stays platform-neutral)
- Users under 13
- Free-text social messaging
- Live instructors or a tutoring marketplace
- Enterprise / classroom admin
- User-generated public courses
- AI-authored canonical learning objectives
- Advertising
- Pay-to-win gamification
- Loot boxes, paid random rewards, or fake currencies
- Recreating another app’s visual system

### Learner goals

- A useful first learning outcome in session one
- A sustainable daily habit
- Progress from foundations toward advanced building
- Specific feedback that improves applied work
- Progress that survives devices and connectivity changes
- A way to demonstrate capability (projects/certificates — certificates are north-star)

### Business goals

- Daily retention as the primary engagement outcome
- Convert after demonstrated value, not at the door
- Curriculum expandable without app releases
- Backend that can later support Android

---

## Book II — North star

The complete Syntholo. This is the product we are building toward. **Do not implement a STAR item in 1.0 unless Book III also lists it.**

### STAR-1 Living campus

Personalized daily mission, evolving mastery map, weekly challenge, real project unlocks, coach continuity, lesson-completion celebration, preview of the next idea.

### STAR-2 Full launch curriculum

All learners can complete:

1. **AI Foundations** — models, limitations, prompting, evaluation, safety, responsible use
2. **AI for School** — research, studying, source verification, writing support, organization
3. **AI for Work and Productivity** — research, communication, analysis, workflows, automation
4. **Content Creation with AI** — ideation, writing, visuals, production, publishing
5. **Build AI Apps and Automations** — coding foundations, APIs, automation, agents, testing, product development

Path switches never destroy shared or path-specific progress.

### STAR-3 Lesson formats

Short captioned video; swipe/scroll concept; multiple-choice and multi-select; ordering, matching, classification, error-spotting; prompt construction and revision; output comparison; scenario workflow design; applied projects with milestones; spaced review and daily challenge.

### STAR-4 Game layer

XP from completed learning only. Capability titles (e.g. Applied Thinker, Systems Builder). Weekly quests. Weekly leagues with promotion/demotion. Team quests and shared streaks. Badges and cosmetic titles. Project and certificate unlocks.

### STAR-5 Social campus

Opt-in community hub, friends, discover via mutual friends and shared programs (never precise location), preset reactions, shared challenges, report, block, invite codes that are single-use or expire in 24 hours.

### STAR-6 Pro depth

Unlimited lessons, unlimited coach revisions, full program downloads and offline starts, applied projects, **verified certificates** (Syntholo-issued completion credentials — not accreditation; copy must never imply a degree, license, or employer-recognized exam).

### STAR-7 Admin portal

Private web app: roles for authors, reviewers, publishers, admins. Draft → review → schedule → publish → archive → rollback. Lesson builder, iPhone-size preview, asset rights metadata, immutable published versions, audit history.

### STAR-8 Screen inventory (~56 plus system states)

Onboarding (10), learning (12), practice/coach (8), social (9), subscription (7), profile/settings (10), plus loading/empty/error/offline/permission states.

Keep this inventory as the destination IA. First ship uses a subset (Book III.D).

---

## Book III — First ship (App Store 1.0)

This is the only P0 that blocks submission. Everything else is a later amendment or a STAR item.

### III.A What 1.0 must do

A new learner aged 13+ can:

1. Confirm age, choose a goal, set experience, pick a path, pick a coach mode, create an account.
2. Complete a first Foundations lesson in the first session, including one applied check.
3. Receive rubric-based feedback when the lesson is AI-evaluated, or instant deterministic feedback when it is objective.
4. Revise once if the activity allows revision.
5. Land on Learn (Today) with a next action, streak, and XP that survive kill/relaunch.
6. Hit a visible free-lesson limit and see a honest StoreKit paywall.
7. Restore purchases, delete the account, and use the app with VoiceOver and Dynamic Type on the core flows.
8. Finish an already-started cached lesson offline. Pro may start a downloaded Foundations lesson offline. AI scoring waits for network.

That loop is the product. If it is excellent, Syntholo is real. If leagues exist and this loop is mediocre, Syntholo is not.

### III.B SHIP requirements

**Identity and onboarding**

- **SHIP-AGE.** Cannot create an account without confirming 13+. Do not collect birth date unless a later legal amendment requires it.
- **SHIP-TEEN.** Ages 13–17: same core curriculum; profile **not discoverable** by default; no public ranking surfaces; no free-text social (already LAW-14).
- **SHIP-AUTH.** Apple, Google, email/password. Sign in with Apple remains available whenever any third-party login is offered.
- **SHIP-ONBOARD.** Collect: goal, experience, recommended path (editable), coach mode, daily goal (may default to a Remote Config value). Notifications are optional and come **after** the first lesson, never as a blocker.
- **SHIP-FIRST-LESSON.** Account exists before progress syncs. The first lesson starts the same session as onboarding. Do not insert catalog browsing, paywall, or social before that lesson.

**Curriculum**

- **SHIP-FOUNDATIONS.** AI Foundations is complete enough for a first-week outcome: **at least 3 modules, 12 lessons, 1 applied capstone project** (project unlocks for Pro; free learners can view the brief and complete non-certificate checkpoints as content allows — see SHIP-PROJECT).
- **SHIP-ONE-PATH.** The learner’s chosen specialization includes **at least 2 modules / 8 lessons** of real content.
- **SHIP-SHELLS.** The other three specializations appear in the catalog as real program records with title, promise, and “more modules arriving” — not fake lessons, not hidden.
- **SHIP-VERSIONS.** Published lesson versions are immutable. Edits create a new version. Historical attempts keep their rubric and content references.
- **SHIP-PUBLISH.** A private publish path exists (admin UI or constrained operator tool) with draft, publish, and rollback. Ugly is allowed. Unversioned JSON dropped into the client is not.

**Learning engine**

- **SHIP-FORMATS.** Support: concept (scroll), objective quiz (single and multi), one interactive type (matching **or** ordering), prompt builder, AI feedback, revision, results, short video with captions/transcript **or** a still-diagram equivalent if a lesson has no video.
- **SHIP-OBJECTIVE.** Objective items score on-device deterministically, then queue progress. No model call.
- **SHIP-PLAYER.** Every lesson declares version, objective, expected duration, and completion rule.
- **SHIP-LIMIT.** Free users start at most 3 newly started lessons per learner-day. Allowance is visible before the limit. Starting a fourth requires Pro or waiting. See III.C for what counts.
- **SHIP-OFFLINE-FREE.** Already-started cached lessons remain completable offline. Starting another free lesson requires online allowance check.
- **SHIP-OFFLINE-PRO.** Pro can download Foundations (and the chosen path when packaged) and start downloaded lessons offline. AI, social, and purchases stay online-only.
- **SHIP-QUEUE.** Local attempts get stable IDs before submit. UI distinguishes: saved locally, awaiting evaluation, syncing, synced, failed. Termination and reboot do not drop the queue.

**AI coach**

- **SHIP-MODES.** All five modes exist as a tone renderer. Default is Supportive.
- **SHIP-SPLIT.** Pipeline is: moderate input → load immutable rubric → model returns **structured score object** → server validates bounds/criteria/evidence → **separate tone pass** (or templated tone) → client. One model call may not freely mix score and vibe.
- **SHIP-FEEDBACK.** Feedback states what worked, what to improve, and one next action. Coach asks the learner to revise rather than doing assessed work for them.
- **SHIP-IDENTITY.** Coach is identified as AI-generated in the UI.
- **SHIP-FOLLOWUP.** Learner may ask follow-up questions about **this feedback**. Free cap: **3 follow-ups per scored attempt**. Pro: unlimited within abuse/rate limits.
- **SHIP-REVISION-FREE.** Free: **1 revision** per AI-evaluated activity. Pro: unlimited within abuse/rate limits. Revisions never consume a new-lesson credit.
- **SHIP-FAIL-SOFT.** AI timeout or invalid schema: save attempt, retry without consuming another lesson credit, show recoverable delay. Server may repair-retry once.

**Engagement (thin)**

- **SHIP-TODAY.** Learn tab is the campus home: daily mission (the next recommended lesson), streak, XP, next-lesson preview.
- **SHIP-XP.** XP only from completed learning activities and the capstone checkpoints. Server-authoritative.
- **SHIP-STREAK.** Streak increments on a learner-day with ≥1 completed lesson (or completed daily mission). No streak freeze purchase. Streak repair, if any, cannot mark uncompleted lessons complete.
- **SHIP-PRACTICE.** Practice tab: skill review of completed **objective** items + a daily challenge. Daily challenge that is review does **not** consume a lesson credit. A challenge that is a new lesson **does**.

**Monetization**

- **SHIP-FREE-CURRICULUM.** Free users may take any **published 1.0 lesson** subject to the daily start limit. Do not lock Foundations behind paywall.
- **SHIP-PRO.** Unlimited new-lesson starts, unlimited coach revisions/follow-ups within rate limits, program downloads, capstone project submission and certificate **when certificates exist**. In 1.0, Pro still unlocks the capstone project submission even if certificates are a later STAR.
- **SHIP-STOREKIT.** StoreKit 2, localized prices, trial/renewal/cancel copy, verify before entitlement, listen for transaction updates, restore, manage subscription, pending/canceled/failed/refunded/expired/billing-retry, no duplicate purchase while pending.
- **SHIP-PAYWALL-TIMING.** Paywall is allowed at limit-reached and from Membership. It is not allowed before the first completed lesson.

**Social (bounded, not empty, not a campus)**

- **SHIP-SOCIAL-TAB.** Social tab exists. 1.0 contents: own profile preview, friends list, friend request (accept required), preset reactions on **learning completions visible to friends**, report, block.
- **SHIP-NO-LEAGUE.** No weekly leagues, leaderboards, team quests, or shared streaks in 1.0. Do not ship a dead leaderboard.
- **SHIP-NO-DISCOVER.** No “discover learners” beyond invite code or handle search that requires an exact match. Invite codes: single-use or 24-hour expiry.
- **SHIP-BLOCK.** Block immediately removes visibility, reactions, and pending requests both ways, including cached social surfaces.

**Profile and operations**

- **SHIP-PROFILE.** Profile, learning settings, coach settings, notifications, membership, privacy/safety, help/support.
- **SHIP-DELETE.** In-app account deletion and a data-export request path.
- **SHIP-DOWNLOADS.** Download manager for Pro lesson packages; free users do not get full-program download.
- **SHIP-A11Y.** VoiceOver, Dynamic Type without clipping, captions/transcripts for instructional video, Reduce Motion, contrast, non-color status, 44 pt targets, on every SHIP flow.
- **SHIP-ANALYTICS.** Core funnel events from Book VI, with LAW-19 restrictions.
- **SHIP-APPCHECK.** App Check required for production functions where supported.
- **SHIP-PROJECT.** One Foundations capstone with structured milestones. Submission and coach review are Pro. Certificate PDF/share is STAR unless already cheap to include as a simple completion card.

**Explicitly not in 1.0**

- Full five-path depth
- Weekly leagues, promotion/demotion, team quests, shared streaks
- Discover-learners graph beyond exact invite/handle
- Verified certificate system as a credential product
- Seasonal events, office hours, family plans
- Additional interactive templates beyond SHIP-FORMATS
- iPad layout, Android, extra languages
- Guest mode without account (progress would have nowhere safe to live)

### III.C Metering rules (closed)

A **newly-started lesson** consumes one free credit when the learner **starts** it while free, after server allowance succeeds.

| Activity | Consumes free credit? | Notes |
| --- | --- | --- |
| Start a lesson the learner has never started this version of | Yes | Requires online check for free users |
| Resume / finish an already-started lesson | No | Including offline finish |
| Revision of the same attempt | No | Free capped at 1 (SHIP-REVISION-FREE) |
| Coach follow-up questions | No | Free capped at 3 |
| Objective skill review of completed items | No | Practice tab |
| Daily challenge that is review | No | |
| Daily challenge that is a new lesson | Yes | Treat as a lesson start |
| Abandoned start, then resume same ID | No | Same attempt ID |
| Replaying a completed lesson for practice | No | Does not re-grant XP |

Pro users are not credit-limited. Abuse rate limits still apply.

### III.D 1.0 screen list (build these)

**Onboarding:** Welcome → age 13+ → goal → experience → path recommendation (editable) → coach mode → account → first-lesson handoff. Daily goal may be a default with an edit later in settings. Notifications after first results.

**Learn:** Today, programs catalog, path switcher, program detail, module detail, video or concept lesson, quiz, prompt builder, AI feedback, revision, results.

**Practice:** Practice hub, daily challenge, skill review, coach conversation (tied to an attempt), coach tone settings, saved feedback, practice history, offline queue status.

**Social:** Community hub (friends-first empty state), friends list, learner profile preview, friend request, preset reactions + safety, report, block. No league, no leaderboard, no discover grid.

**Subscription:** Daily counter, limit reached, Pro benefits, plan selection, purchase pending/success, restore.

**Profile:** Profile, achievements (only those 1.0 can actually award), downloads, learning settings, coach settings, notifications, membership, privacy and safety, help.

Loading, empty, error, offline, permission states are required companions, not a separate backlog.

### III.E Primary flows (1.0)

**New learner:** Launch → welcome → age → goal → experience → path → coach → account → first lesson → results → optional notifications → Today.

**Daily:** Launch/notification → Today → daily mission → lesson → apply → feedback → optional revision → results → next preview.

**Practice:** Practice hub → review or challenge → score → explanation → optional coach follow-up → mastery update.

**Subscription:** Visible counter → limit reached → benefits → StoreKit → verified entitlement → resume interrupted lesson.

**Social:** Friends → profile → request or preset reaction → server validation → update. Block/report from every profile.

---

## Book IV — Learning and coach system

### Curriculum ownership

- Experts define objectives, explanations, examples, rubrics, acceptable answers, and safety boundaries.
- AI personalizes examples, hints, practice variants, and **tone of feedback**.
- AI does not invent canonical objectives.
- Published versions are immutable.

### Lesson structure (every complete lesson)

1. State the learning objective  
2. Explain with a visual model or short video  
3. Check recall or comprehension  
4. Apply to a realistic scenario  
5. Receive rubric-based or deterministic feedback  
6. Revise when the activity allows  
7. Record mastery, XP, streak, next recommendation  

### Coach requirements

- Five modes: Supportive, Funny, Strict, Chill, Socratic  
- Explanation level is independent  
- Score object is mode-agnostic  
- Unsafe requests get a boundary and a curriculum-appropriate redirect  
- Evaluation flow:

  1. Client sends lesson ID, rubric version, response, coach mode, attempt ID  
  2. Server verifies auth, App Check, access, lesson state, allowance  
  3. Input moderation  
  4. Load immutable rubric  
  5. Structured score from the model  
  6. Validate bounds, criteria, evidence, completeness  
  7. Persist attempt + rubric version  
  8. Render tone-specific feedback  

### Cost and failure envelope

- Prefer deterministic items. AI is for applied work that needs judgment.
- Prompt-cache stable rubric prefixes.
- Model ID is Remote Config, never compiled-in product logic.
- Visible AI failure (learner sees retry/delay) target: **< 2%** of evaluation requests, or an approved remediation plan before expanded TestFlight.
- Production model and fallback model are chosen with a fixed evaluation suite before the AI-coach phase exits. Until then, development may use a cheaper model **with the same schema**.

---

## Book V — Architecture and data

### Client

- Native SwiftUI, Observation, typed `NavigationStack` routes  
- Four-tab shell: Learn, Practice, Social, Profile  
- Local lesson cache + durable progress queue  
- StoreKit 2  
- Firebase Apple SDK via SPM  
- No Firebase/OpenAI in the foundation slice; they arrive in identity and later phases  

### Server

- Cloud Functions: trusted mutations, AI proxy, scoring, daily limits, XP, streaks, social actions, entitlements  
- Firestore: metadata and bounded documents, not video blobs  
- Storage: video, captions, illustrations, lesson packages, certificate assets (when they exist)  
- Security Rules deny direct client writes to derived state (XP, streaks, leagues, entitlements, etc.)

### Logical entities (1.0 must have a home for)

`users`, `publicProfiles`, `preferences`, `programs`, `programVersions`, `modules`, `lessonVersions`, `enrollments`, `lessonAttempts`, `progress`, `masterySkills`, `savedFeedback`, `downloadManifests`, `friendships`, `friendRequests`, `blocks`, `achievements`, `subscriptions`, `notificationPreferences`, `moderationReports`, `featureConfiguration`

North-star entities, schema-ready but unused in 1.0 UI: `sharedChallenges`, `leagueSeasons`, `leagueEntries`, `certificates`

### Offline

See SHIP-OFFLINE-*. Content-version mismatch: preserve work, request the referenced rubric version, do not silently re-score against a new rubric.

### Error catalog (required states)

| Failure | Required behavior |
| --- | --- |
| AI timeout | Save attempt; retry; no extra credit consumed |
| Invalid AI schema | One server repair retry, then recoverable delay |
| Content unavailable | Keep place; offer another cached lesson |
| Progress sync failure | Queue, exponential backoff, do not block navigation |
| Auth expiry | Keep local work; refresh; resume |
| Purchase canceled | Return to plan selection; no error-shame copy |
| Purchase pending | Pending UI; no second purchase |
| Verification failure | No entitlement; retry + support |
| Restore failure | Explain Apple Account; support |
| Social conflict | Show authoritative relationship |
| Block | Drop cached shared surfaces immediately |
| Outage | Downloaded learning still works; online features explain unavailability |

---

## Book VI — Privacy, safety, accessibility, analytics

### Privacy

- Confirm 13+; avoid birth dates  
- Warn: do not paste secrets, school-identifying data, employer data, or other people’s information into the coach  
- Minimize raw prompt retention; restrict staff access  
- Vendor config must prohibit training on Syntholo customer inputs  
- Analytics exclude raw prompt/response  
- Export + delete  
- App Store privacy labels  
- Consent for profile discovery (default off for 13–17) and de-identified quality analysis  
- Retention periods documented before Closed TestFlight (still an open legal fill-in, not a product-scope hole)

### Social safety (all versions)

- Social is opt-in  
- Preset reactions only  
- Friend accept required  
- No precise location  
- Report on every profile  
- Staff-auditable moderation actions  
- Real name, exact location, email, phone never public by default  

### Accessibility (P0 on SHIP flows)

VoiceOver labels/order/actions; Dynamic Type; captions/transcripts; Reduce Motion; contrast; non-color status; 44 pt targets; Switch Control where applicable; text alternatives for mastery graphics.

### Analytics events (1.0)

onboarding started/completed; age confirmed; goal selected; path recommended/selected/switched; coach mode selected/changed; account created/login completed; program/module/lesson viewed; lesson started/completed/abandoned; activity submitted/scored/revised; AI evaluation requested/completed/failed; daily mission started/completed; practice review started/completed; achievement unlocked; friend request/reaction; lesson limit viewed/reached; paywall viewed; plan selected; purchase started/completed/pending/failed/restored; download started/completed/removed; notification permission/preference; report/block/support; account deletion requested/completed.

Stable names, versioned properties, validated in debug and tests.

### Success metrics (hypotheses, not silent kill-switches)

Recalibrate after TestFlight.

| Indicator | Initial hypothesis |
| --- | --- |
| Onboarding completion | 65% |
| First-lesson completion | 55% |
| Lesson completion after start | 75% |
| Coach users who revise at least once | 60% |
| Visible AI failure | < 2% |
| Crash-free sessions | 99.8% at submission |
| D1 / D7 | 40% / 22% |
| Free → paid in 30 days | 3% (6% stretch) |
| Annual trial → paid | 45% |

Guardrails to dashboard: deletion failures, entitlement mismatch, progress-loss reports, AI safety escalations, social report/block rate, notification opt-out, accessibility defects.

Experiments (Remote Config) may test onboarding copy/order, daily goal default, reminder timing, recommendation presentation, paywall **after** value, plan ordering. Experiments may not violate LAW-5 or LAW-7.

---

## Book VII — Delivery

Quality gates, not a calendar.

### Phases

| Phase | Plan file | 1.0 outcome | Exit |
| --- | --- | --- | --- |
| 0 | `2026-08-25-syntholo-ios-foundation.md` | Reproducible app, design system, 4-tab shell, CI | Clean test on iOS 17 simulator |
| 1 | identity/onboarding (to be authored) | Age, auth, profile, first-lesson handoff | Learner reaches Learn with persisted profile |
| 2 | curriculum platform (to be authored) | Versioned schema, publish, sync | Fixture course renders and rolls forward safely |
| 3 | learning engine (to be authored) | Player, formats, progress, limits, offline queue | One module survives interruption |
| 4 | AI coach (to be authored) | Five tones, split scoring, safety | Structured feedback is explainable and mode-stable |
| 5 | engagement (to be authored) | Today, streak, XP, daily challenge, review | Rewards never block recovery |
| 6 | subscriptions (to be authored) | StoreKit, paywall, restore, limits | Sandbox matrix + server reconciliation |
| 7 | social (to be authored) | **1.0 social only** (SHIP-SOCIAL-*). No leagues | Safety review of preset-only flow |
| 8 | profile/operations (to be authored) | Settings, downloads, privacy, support, analytics | Deletion, export, telemetry |
| 9 | App Store hardening (to be authored) | a11y, privacy manifest, TestFlight, submission | GATE-STORE |

Phase 7 in the historical roadmap mentioned leagues. **This bible removes leagues from 1.0.** The phase still exists for friends/reactions/block.

### Milestones

**GATE-ALPHA (internal)** — Phases 0–4. Foundations sample published. Onboarding → one lesson → coach → progress sync → offline recovery. Privacy threat model for 13–17, AI, stored work. No known progress-loss or duplicate-reward defect. Security Rules deny protected writes. AI schema suite passes.

**GATE-TF-CLOSED** — Phases 5–7 (1.0 social, not leagues). StoreKit sandbox matrix. Critical a11y. Privacy policy, terms, support. Zero open critical security, safety, purchase, or data-loss defects. Retention baselines recorded.

**GATE-TF-EXPANDED** — Phase 8. Editorial QA on every published 1.0 lesson version. Notifications, downloads, deletion, export. Load tests for completion + AI bursts. No open P0/P1 crash, data-loss, purchase, or safety defects. Crash-free approaching 99.8%. Visible AI failure < 2% or approved plan.

**GATE-STORE** — Phase 9. 99.8% crash-free. Privacy labels, deletion, subscription disclosures, reviewer demo account, review notes, monitoring/rollback owners. App Review can reach purchase and account management.

### Every-phase checklist

- Traced to SHIP/LAW IDs  
- Failing test first where feasible  
- Error/empty/loading/offline/retry/a11y with happy path  
- LAW-19 analytics  
- Remote config cannot weaken safety or entitlements  
- Idempotent server mutations + Rules + App Check  
- String Catalogs; Dynamic Type  
- No merge with known data loss, entitlement bypass, unsafe AI path, or inaccessible critical flow  

### Plan authoring order

1. Execute foundation.  
2. Author identity + curriculum plans against real interfaces.  
3. Author learning engine + AI coach after the content schema is proven with fixtures.  
4. Author engagement, subscriptions, social after progress semantics are stable.  
5. Author operations + hardening last.

---

## Book VIII — Change control

After this bible is accepted, it is the release source of truth.

1. Scope additions require a dated amendment in this file.  
2. Every addition names a **removed** requirement, a **changed gate**, or an **accepted delay**.  
3. LAW and SHIP items may not be silently downgraded.  
4. Pricing, daily limits, age, platforms, curriculum paths, social capabilities, and data practices need explicit product approval.  
5. Technical internals may change without amendment if user-visible behavior, acceptance criteria, privacy, safety, and SHIP scope stay the same.  
6. Slice plans may not introduce STAR features. If a plan needs a STAR feature, amend Book III first.

### Remaining fill-ins (do not block Book III authoring)

| Decision | Owner | Blocks |
| --- | --- | --- |
| Production AI model + fallback, via evaluation suite | Eng, Product, Safety | Phase 4 exit |
| Retention periods for prompts, attempts, diagnostics, deletion | Legal, Privacy, Eng | GATE-TF-CLOSED |
| TestFlight cohort sizes and observation windows | Product, Data, Eng | GATE-TF-EXPANDED |
| Which specialization is the first fully-built path (School / Work / Creation / Build) | Product | Phase 2 content load |

Localized prices are not a product decision. StoreKit displays them.

---

## Book IX — Contradiction log (resolved)

| Was | Now |
| --- | --- |
| PRD P0 “four coach modes” vs five listed | **Five** (DEC-6) |
| “No blocking questions” while iOS version open | **iOS 17.0** (DEC-1) |
| Foundations “before or alongside” specialization | First session is **Foundations**. Specialization may be **previewed** after the first Foundations lesson; full path content follows SHIP-ONE-PATH |
| PRD P0 = 56 screens, 5 full paths, leagues, certificates | **Split:** Book II north star / Book III first ship |
| Free “unlimited coach revisions” unspecified | Free **1 revision** + **3 follow-ups** per scored attempt |
| Practice vs daily limit unspecified | Metering table in III.C |
| “Verified certificates” sounded like accreditation | STAR-6: Syntholo-issued completion only |
| Roadmap Phase 7 included leagues in Closed TestFlight | Leagues are STAR. Phase 7 is friends/reactions/block |
| Status “approved, pending review” | This bible is the binding document once accepted |

---

## Book X — Agent operating protocol

When implementing:

1. Read **Book I laws** and **Book III SHIP** for the slice.  
2. Open the slice plan. If the plan asks for a STAR-only feature, stop and report the conflict.  
3. TDD: failing test → minimal implementation → pass → commit.  
4. Do not add Firebase, OpenAI, or StoreKit in Phase 0.  
5. Do not add leagues, certificates, or extra paths because they appear in the old PRD.  
6. Every PR description cites the SHIP/LAW IDs it implements.  
7. If unsure, prefer the smaller interpretation that still satisfies the SHIP item.

Foundation slice reminder (Phase 0): reproducible XcodeGen project, design tokens, four-tab shell, environment contract, CI, no networking. Visual direction: warm grouped canvas, ink typography, academic blue accent, supporting green/gold/coral for **states**, tight spacing, limited rounding, geometric diagrams — original, not a clone.

---

## Acceptance for this bible

This document is accepted when the founder agrees that:

- Agents must refuse STAR work during 1.0  
- Book III is the App Store contract  
- Book I laws are non-negotiable  
- Old PRD and roadmap yield on conflict  

Until that agreement, treat this file as the proposed constitution.

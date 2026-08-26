# Syntholo iOS MVP Product Requirements Document

**Status:** Approved design, pending final written review  
**Date:** August 25, 2026  
**Product:** Syntholo for iPhone  
**Release target:** App Store-ready MVP, quality-gated without a fixed deadline  
**Document role:** Product contract and source of truth through App Store release

## 1. Executive summary

Syntholo is a native iPhone learning app that teaches practical AI skills through short lessons, interactive exercises, expert-designed curricula, and personalized AI coaching. Learners begin with shared foundations, then specialize in school, work, content creation, or building AI products and automations.

The app combines the habit-forming clarity of a daily learning product with the credibility of a professional school. It uses a structured curriculum, published assessment rubrics, applied projects, visible mastery, and restrained gamification. The first release serves users aged 13 and older in English.

The MVP is freemium. Free learners can complete three lessons per day with access to the full curriculum. Syntholo Pro provides unlimited lessons, unlimited coach revisions, complete offline downloads, projects, and certificates for $9.99 monthly or $69.99 annually. The annual plan includes a seven-day free trial.

## 2. Problem statement

People encounter AI tools faster than they can develop reliable skills for using them. Existing education is often passive, fragmented, overly technical, or focused on isolated prompt tricks instead of durable capability. Learners need a guided path that begins with responsible everyday use and progresses toward automation, coding, and building AI products.

Without a structured and engaging learning system, users repeat shallow tutorials, accept unreliable outputs, expose sensitive information, and fail to convert experimentation into practical skill.

## 3. Target audience

### Primary users

- Learners aged 13 and older who are new to AI.
- Students using AI for research, studying, writing, and organization.
- Professionals applying AI to research, communication, analysis, and workflows.
- Creators using AI for ideation, production, and publishing.
- Aspiring builders learning automation, coding, agents, and AI application development.

### Launch constraints

- English only, with localization-ready content and interface architecture.
- iPhone only for the initial release.
- No support for children under 13.
- No organization, classroom, parent, or teacher administration in the MVP.

## 4. Product principles

1. **Teach durable skills.** Explain mental models, evaluation, limitations, and responsible use rather than memorized tricks.
2. **Make learners act.** Every module combines instruction with applied interaction.
3. **Keep standards stable.** Coach tone may change; assessment rubrics do not.
4. **Show why.** AI scores cite visible rubric criteria and actionable evidence.
5. **Respect attention.** Engagement supports learning and avoids dark patterns.
6. **Protect trust.** Privacy, safety, accessibility, and purchase clarity are release requirements.
7. **Build for change.** Curriculum, models, prompts, limits, and experiments remain remotely configurable.

## 5. Goals

### Learner goals

- Reach a useful first learning outcome during the first session.
- Build a sustainable daily learning habit.
- Progress from foundational AI use to advanced building skills.
- Receive specific feedback that improves applied work.
- Preserve progress across devices and connectivity changes.
- Demonstrate capability through projects and certificates.

### Business goals

- Establish daily retention as the primary engagement outcome.
- Convert learners to Pro after demonstrating meaningful product value.
- Create a curriculum and content system that can expand without app releases.
- Build a technical foundation that can support Android later.

## 6. Non-goals

- **Android, iPad, macOS, and web learner apps:** The backend remains platform-neutral, but the MVP targets iPhone.
- **Users under 13:** Parental consent and child-specific compliance are a separate release.
- **Free-text social messaging:** Preset reactions provide encouragement without introducing a moderation-heavy chat system.
- **Live instructors or tutoring marketplace:** The MVP uses curriculum and AI coaching.
- **Enterprise and classroom administration:** Teams, schools, seats, and teacher dashboards are future initiatives.
- **User-generated public courses:** Curriculum is published through Syntholo’s private content portal.
- **AI-generated core curriculum:** AI personalizes examples and feedback but does not define canonical learning objectives.
- **Advertising:** Monetization is limited-free plus paid subscription.
- **Pay-to-win gamification:** Purchases never alter XP, league scoring, mastery, or social rank.

## 7. Launch curriculum

All learners begin with shared AI Foundations before or alongside their specialization.

1. **AI Foundations** — models, limitations, prompting, evaluation, safety, and responsible use.
2. **AI for School** — research, studying, source verification, writing support, and organization.
3. **AI for Work and Productivity** — research, communication, analysis, workflows, and automation.
4. **Content Creation with AI** — ideation, writing, visuals, production workflows, and publishing.
5. **Build AI Apps and Automations** — coding foundations, APIs, automation, agents, testing, and product development.

Learners may switch paths without losing shared or path-specific progress.

## 8. Learning model

### Curriculum ownership

- Experts define learning objectives, explanations, examples, rubrics, acceptable answers, and safety boundaries.
- AI personalizes examples, hints, practice variants, and feedback.
- Published lesson versions are immutable.
- Updated content creates a new version while historical attempts retain their original rubric and content references.

### Lesson formats

- Short video with captions and transcript.
- Swipeable or scrollable concept explanation.
- Multiple-choice or multi-select knowledge check.
- Ordering, matching, classification, and error-spotting interactions.
- Prompt construction and revision.
- Output comparison and evaluation.
- Scenario-based workflow design.
- Applied projects with structured milestones.
- Spaced skill review and daily challenge.

### Lesson structure

1. State the learning objective.
2. Explain the concept with a visual model or short video.
3. Check recall or comprehension.
4. Apply the concept to a realistic scenario.
5. Receive rubric-based feedback.
6. Revise when appropriate.
7. Record mastery, XP, streak, and next recommendation.

## 9. AI coach

### Coach modes

- Supportive
- Funny
- Strict
- Chill
- Socratic

“Beginner-friendly,” “intermediate,” and “advanced” are explanation-level settings, not personalities.

### Coach requirements

- Rubric scores remain identical across coach modes.
- Tone changes presentation only.
- Feedback names what worked, what needs improvement, and one recommended next action.
- The coach asks the learner to revise rather than completing assessed work for them.
- Learners can ask follow-up questions about feedback.
- The coach clearly identifies itself as AI-generated.
- Unsafe or disallowed requests receive a safe boundary and curriculum-appropriate redirection.

### Evaluation flow

1. Client submits the lesson ID, rubric version, response, and selected coach mode.
2. Server verifies authentication, App Check, access, lesson state, and daily allowance.
3. Input moderation and safety checks run.
4. The trusted service loads the immutable rubric and scoring instructions.
5. The model returns a structured result conforming to a strict schema.
6. Server validates score bounds, criteria, evidence, and response completeness.
7. The attempt and rubric version are stored.
8. Tone-specific feedback is returned to the learner.

Objective activities score deterministically without AI.

## 10. Engagement and gamification

### Living campus system

- Personalized daily mission.
- Evolving capability and mastery map.
- Weekly challenge.
- Real project unlocks.
- Coach continuity across lessons and practice.
- Lesson-completion celebration.
- Preview of the next compelling idea.

### Game layer

- XP earned only through completed learning activities and projects.
- Capability levels such as Applied Thinker and Systems Builder.
- Weekly quests that rotate learning behaviors.
- Weekly leagues with clear promotion and demotion zones.
- Team quests and shared streaks.
- Achievement badges and cosmetic profile titles.
- Project and certificate unlocks.

### Guardrails

- Purchases never affect XP, leagues, mastery, or rank.
- No loot boxes, random paid rewards, or artificial currencies.
- Session length is not a success metric.
- Streak recovery cannot falsify learning completion.
- Notifications are optional and independently controllable.
- League points reset on a predictable schedule.

## 11. Information architecture and screen inventory

The MVP contains approximately 56 product screens plus reusable loading, empty, error, offline, and permission states.

### 11.1 Onboarding and identity

1. Welcome and value proposition.
2. Age confirmation (13+).
3. Primary goal selection.
4. AI experience level.
5. Path recommendation.
6. Coach mode selection.
7. Daily learning goal.
8. Account creation.
9. Notification explanation and optional permission request.
10. Learning-plan confirmation and first-lesson handoff.

### 11.2 Learning and curriculum

1. Today dashboard.
2. Programs catalog.
3. Path switcher.
4. Program detail.
5. Module detail.
6. Video lesson.
7. Concept lesson.
8. Quiz.
9. Prompt builder.
10. AI feedback.
11. Revision.
12. Lesson results.

### 11.3 Practice and AI coach

1. Practice hub.
2. Daily challenge.
3. Skill review.
4. Coach conversation.
5. Coach tone settings.
6. Saved feedback.
7. Practice history.
8. Offline queue.

### 11.4 Social and motivation

1. Community hub.
2. League overview.
3. Leaderboard.
4. Friends list.
5. Discover learners.
6. Learner profile preview.
7. Friend request.
8. Shared streak or team quest.
9. Preset reactions and safety controls.

### 11.5 Subscription and limits

1. Free daily lesson counter.
2. Limit reached.
3. Pro benefits.
4. Plan selection.
5. Apple purchase confirmation state.
6. Purchase success.
7. Restore purchases.

### 11.6 Profile and settings

1. Profile.
2. Achievements.
3. Certificates.
4. Downloads.
5. Learning settings.
6. Coach settings.
7. Notifications.
8. Membership.
9. Privacy and safety.
10. Help and support.

## 12. Primary user flows

### New learner

Launch → welcome → age confirmation → goal → experience → path recommendation → coach → daily goal → account → first lesson → results → optional notification prompt → Today dashboard.

### Daily learning

Notification or launch → Today dashboard → daily mission → lesson → applied exercise → feedback → revision → results → unlock or next-lesson preview.

### Practice

Practice hub → personalized review set or daily challenge → response → scoring → explanation → optional coach follow-up → mastery update.

### Subscription

Daily counter or completed lesson → value preview → limit reached → Pro benefits → plan selection → StoreKit purchase → verified entitlement → resume interrupted lesson.

### Social

Community → friends or league → profile/activity → preset reaction, friend request, or shared challenge → server validation → activity update.

## 13. Monetization

### Free plan

- Complete access to all launch paths.
- Three completed lessons per day.
- Same canonical curriculum and scoring quality as Pro.
- May finish an already-started lesson offline.
- Requires connectivity to start another free lesson so allowance can be verified.

### Syntholo Pro

- Unlimited lessons.
- Unlimited AI-coach revisions.
- Complete program downloads and offline starts.
- Applied projects and verified certificates.
- $9.99 per month.
- $69.99 per year.
- Seven-day free trial on annual plan only.

### Purchase requirements

- Use StoreKit 2 and one auto-renewable subscription group.
- Display localized App Store pricing rather than hard-coded purchase prices.
- Clearly state trial, renewal, cancellation, and billing terms.
- Verify every transaction before granting entitlement.
- Monitor current entitlements, unfinished transactions, and transaction updates.
- Provide Restore Purchases and Manage Subscription access.
- Handle pending, canceled, failed, refunded, expired, and billing-retry states.
- Never start a duplicate purchase while one is pending.

## 14. Social safety

- Social features are opt-in.
- No free-text direct messages, comments, or status posts.
- Reactions use a curated preset library.
- Friend requests require explicit acceptance.
- Discovery uses mutual friends and shared programs, not precise location.
- Invite codes are single-use or expire after 24 hours.
- Blocking immediately removes profile visibility, shared activity, rankings, and shared challenges between both users.
- Reporting is available from every learner profile.
- Moderation and safety actions are auditable by authorized staff.
- Real names, exact location, email, and phone number are never publicly displayed by default.

## 15. Visual and interaction design

### Identity

- Professional-school credibility with a lively editorial layer.
- Warm neutral canvas, strong ink typography, and academic blue as the primary accent.
- Supporting green, gold, and coral identify learning states and editorial graphics.
- Strict spacing, thin dividers, and limited corner rounding.
- Purposeful geometric diagrams instead of decorative AI imagery.

### Interaction

- Native iOS navigation and control behavior.
- Immediate visual response and haptic feedback for meaningful actions.
- Motion explains progression or state change and respects Reduce Motion.
- Gamification is visible but secondary to curriculum and applied work.
- Every status uses text or shape in addition to color.

## 16. Technical architecture

### iOS client

- Native SwiftUI.
- Modern observation for app state.
- `NavigationStack` with typed routes.
- Swift concurrency for asynchronous work.
- Local lesson cache and durable progress queue.
- StoreKit 2 for subscriptions.
- Firebase Apple SDK through Swift Package Manager.
- Minimum supported iOS version chosen at implementation planning after checking current App Store and SDK constraints; the product design assumes modern SwiftUI and StoreKit 2 APIs.

### Firebase

- Authentication: Sign in with Apple, Google, and email/password.
- Firestore: users, curricula, progress, attempts, social graph, leagues, subscriptions, and configuration.
- Storage: videos, captions, illustrations, downloadable lesson packages, and certificate assets.
- Cloud Functions: trusted mutations, AI proxy, scoring, daily limits, XP, streaks, social actions, leaderboards, certificates, and subscription synchronization.
- Messaging: optional reminders and social notifications.
- Analytics: product events without raw learner prompt content.
- Crashlytics: crash and nonfatal diagnostics.
- App Check: app attestation for protected backend access.
- Remote Config: model configuration, lesson limits, feature flags, safe experiments, and operational fallbacks.

### AI service

- OpenAI Responses API called only from trusted server infrastructure.
- Structured output schema for rubric scoring.
- Streaming used for coach conversation where it improves perceived responsiveness.
- Prompt caching used for stable curriculum and rubric prefixes when appropriate.
- Model identifier is remotely configurable and never embedded as product logic.
- Every response receives schema and policy validation before reaching the client.
- Provider keys never ship in the app.

### Admin portal

- Private web application using Firebase Admin SDK.
- Role-based access for authors, reviewers, publishers, and administrators.
- Draft, review, schedule, publish, archive, and rollback states.
- Lesson builder for text, video, quiz, interactive schema, rubric, and localization fields.
- Content preview at supported iPhone sizes.
- Asset upload, captions, alt text, transcript, and rights metadata.
- Immutable published versions and audit history.

## 17. Core data model

Logical entities include:

- `users`
- `publicProfiles`
- `preferences`
- `programs`
- `programVersions`
- `modules`
- `lessonVersions`
- `enrollments`
- `lessonAttempts`
- `progress`
- `masterySkills`
- `savedFeedback`
- `downloadManifests`
- `friendships`
- `friendRequests`
- `blocks`
- `sharedChallenges`
- `leagueSeasons`
- `leagueEntries`
- `achievements`
- `certificates`
- `subscriptions`
- `notificationPreferences`
- `moderationReports`
- `featureConfiguration`

Videos and large binary content live in Storage. Firestore documents store metadata, structured content, references, and bounded summaries.

## 18. Authoritative state and integrity

- XP, mastery, lesson credits, streaks, league points, achievements, certificates, friendships, blocks, and subscription access are server-authoritative.
- Client retries use idempotency keys.
- An attempt cannot grant XP twice.
- Daily lesson completion uses the learner’s server-defined day boundary.
- Device clock changes cannot create lesson credits or alter streaks.
- Social and leaderboard writes occur through trusted functions.
- Security Rules deny direct writes to protected derived state.
- App Check is required for production functions where supported.

## 19. Offline behavior

### Free learner

- May finish a lesson already started and cached.
- Starting an additional lesson requires online allowance verification.
- Objective work scores locally and queues progress.
- AI-evaluated work queues until connectivity returns.

### Pro learner

- May download full programs.
- May start downloaded lessons offline.
- AI evaluation, social activity, and purchases remain online-only.

### Synchronization

- Local attempts receive stable IDs before submission.
- The UI distinguishes saved locally, awaiting evaluation, syncing, synced, and failed states.
- Server reconciliation grants authoritative rewards exactly once.
- Content-version mismatches preserve work and request the referenced rubric version.

## 20. Error and recovery behavior

- **AI timeout:** Save the attempt and allow retry without consuming another lesson credit.
- **Invalid AI schema:** Retry server-side once with a repair path, then return a recoverable evaluation delay.
- **Content unavailable:** Preserve the learner’s place and offer another cached lesson.
- **Progress sync failure:** Queue with exponential backoff and show state without blocking navigation.
- **Authentication expiry:** Preserve local work, refresh authentication, then resume.
- **Purchase canceled:** Return to plan selection with no error language.
- **Purchase pending:** Show pending status and avoid duplicate purchase attempts.
- **Verification failure:** Do not grant access; offer retry and support.
- **Restore failure:** Explain Apple Account requirements and provide support.
- **Social action conflict:** Return the current authoritative relationship state.
- **Blocked relationship:** Immediately remove cached shared surfaces.
- **Service outage:** Keep downloaded learning available and communicate unavailable online functions.

No expected failure may erase learner-authored work.

## 21. Privacy and data handling

- Confirm users are 13 or older.
- Avoid collecting birth dates unless later required.
- Explain that coach feedback is AI-generated.
- Warn learners not to submit confidential or personal data.
- Minimize raw prompt retention and restrict staff access.
- AI vendor agreements and configuration must prohibit training on Syntholo customer inputs.
- Product analytics exclude raw prompt and response content.
- Support data export and account deletion.
- Publish clear privacy disclosures and App Store privacy labels.
- Provide consent controls for profile discovery and de-identified quality analysis.
- Define production retention periods before beta and document them in the privacy policy.

## 22. Accessibility

- VoiceOver labels, grouping, reading order, and custom actions.
- Dynamic Type without clipping at accessibility sizes.
- Captions and transcripts for all instructional video.
- Reduced Motion support.
- Sufficient contrast in light appearance.
- Non-color indicators for status and scoring.
- Minimum interactive target sizes.
- Keyboard and Switch Control compatibility where applicable.
- Accessible charts and mastery graphics with text alternatives.
- Accessibility QA is required for every P0 flow.

## 23. Analytics

### Core events

- onboarding started/completed
- age confirmed
- goal selected
- path recommended/selected/switched
- coach mode selected/changed
- account created/login completed
- program/module/lesson viewed
- lesson started/completed/abandoned
- activity submitted/scored/revised
- AI evaluation requested/completed/failed
- daily mission started/completed
- practice review started/completed
- achievement/project/certificate unlocked
- friend request/reaction/shared challenge action
- lesson limit viewed/reached
- paywall viewed
- plan selected
- purchase started/completed/pending/failed/restored
- download started/completed/removed
- notification permission and preference changes
- report/block/support action

### Analytics restrictions

- Do not log raw prompts, responses, private profile data, emails, or message content.
- Use stable event names and versioned properties.
- Validate events in debug builds and automated tests.
- Define funnel ownership and dashboards before public beta.

## 24. Success metrics

Initial targets are hypotheses and must be recalibrated after TestFlight establishes baselines.

### Leading indicators

- 65% onboarding completion.
- 55% first-lesson completion.
- 75% lesson completion after start.
- 60% of AI-coach users submit at least one revision.
- Fewer than 2% of AI evaluations require visible system retry or fail.
- At least 99.8% crash-free sessions.

### Retention and business indicators

- 40% day-1 retention.
- 22% day-7 retention.
- At least 20% DAU/MAU learning frequency.
- 3% free-to-paid conversion within 30 days.
- 6% stretch free-to-paid conversion.
- 45% annual-trial-to-paid conversion.

### Guardrail metrics

- Account deletion failure rate.
- Purchase and entitlement mismatch rate.
- Progress-loss reports.
- AI safety escalation rate.
- Social report and block rate.
- Notification opt-out rate.
- Accessibility defect count.

## 25. Experimentation policy

Remote Config may test:

- Onboarding order and explanation.
- Daily goal defaults.
- Reminder timing.
- Lesson recommendation presentation.
- Paywall timing after demonstrated value.
- Annual versus monthly plan ordering.

Experiments may not use false urgency, hidden terms, fabricated scarcity, obstructed cancellation, misleading pricing, weakened privacy, or pay-to-win mechanics.

## 26. Requirements by priority

### P0 — required for App Store MVP

- Native SwiftUI iPhone application.
- 13+ onboarding and all three sign-in options.
- Five launch paths and shared foundations.
- Admin content portal with review and versioned publishing.
- Video, concept, quiz, prompt, evaluation, revision, and results formats.
- Four coach modes with shared scoring rubrics.
- Daily mission, XP, streak, mastery map, quests, achievements, and projects.
- Three free lessons per day.
- Monthly and annual StoreKit subscriptions with annual trial.
- Offline completion and Pro program downloads.
- Practice hub, daily challenge, saved feedback, and history.
- Friends, preset reactions, weekly league, shared challenge, report, and block.
- Profiles, achievements, certificates, downloads, preferences, privacy, and support.
- Analytics, Crashlytics, App Check, Remote Config, and push notifications.
- Account deletion and data export request.
- Accessibility for every core flow.
- Full purchase, safety, offline, and recovery states.

### P1 — high-priority follow-up

- Additional interactive lesson templates.
- Expanded project portfolio presentation.
- More granular coach voices.
- Seasonal curriculum events.
- Richer certificate sharing.
- Improved adaptive placement assessment.
- Instructor-authored live office-hour content without real-time instruction.

### P2 — future consideration

- Android learner app.
- iPad-optimized interface.
- Additional languages.
- Teams, classrooms, teachers, and organization administration.
- Family plans.
- Live instruction.
- Public creator courses.
- Advanced career portfolios and recruiter verification.

## 27. Representative user stories

### New learner

- As a new learner, I want to choose my goal and experience level so that Syntholo recommends an appropriate path.
- As a learner, I want to change my path without losing progress so that my goals can evolve.
- As a learner, I want to select a coach tone so that feedback feels motivating to me.

### Active learner

- As a learner, I want one clear daily mission so that I can begin without deciding what to study.
- As a learner, I want short lessons with active practice so that I can build skill in limited time.
- As a learner, I want to revise applied work after feedback so that scoring leads to improvement.
- As a learner, I want offline access so that connectivity does not prevent progress.

### Social learner

- As a learner, I want to encourage friends safely so that we can build momentum together.
- As a learner, I want fair weekly competition so that I can compare learning activity without pay-to-win mechanics.
- As a learner, I want to block another user immediately so that I control my social experience.

### Subscriber

- As a free learner, I want to understand my daily allowance so that limits never surprise me.
- As a subscriber, I want verified access immediately after purchase so that I can resume learning.
- As a returning subscriber, I want to restore access so that changing devices does not require another purchase.

### Curriculum team

- As an author, I want structured lesson templates so that content is consistent.
- As a reviewer, I want to approve exact versions so that unpublished changes cannot reach learners.
- As a publisher, I want rollback and audit history so that content errors can be corrected safely.

## 28. Acceptance criteria

### Onboarding

- A user cannot complete account creation without confirming age 13+.
- A user can select a goal, experience level, path, coach, and daily goal.
- A user can skip optional notifications without losing access.
- The recommended path and first lesson appear after account creation.

### Learning

- Every lesson declares a version, objective, expected duration, and completion rule.
- Objective scoring is deterministic.
- Open-ended scoring returns all required rubric criteria or a recoverable delay state.
- A failed evaluation does not erase the response or consume another credit.
- Completion grants XP and progress exactly once.
- A learner can view the next recommended action after completion.

### Free limits and subscriptions

- A free learner can complete no more than three newly started lessons per server-defined day.
- The allowance is visible before a learner reaches the limit.
- The paywall shows localized prices and renewal terms.
- Entitlement is granted only for verified StoreKit transactions.
- Restore Purchases recovers valid entitlement.
- Expired, refunded, or revoked entitlement removes Pro access without deleting progress.

### Offline

- An already-started cached lesson remains usable without connectivity.
- Pro users can start downloaded lessons offline.
- Queued work survives termination and device restart.
- Sync grants rewards once and associates the correct content version.

### Social

- Users cannot send free-text messages.
- Friend requests require acceptance.
- Preset reactions pass server validation.
- Blocking removes mutual visibility and active shared challenges immediately.
- League scoring cannot be written directly by the client.

### Privacy and accessibility

- Account deletion is available in-app.
- Analytics contain no raw prompt or response text.
- All P0 screens pass VoiceOver, Dynamic Type, contrast, caption, and reduced-motion review.

## 29. Testing strategy

### Automated

- Unit tests for lesson limits, XP, streaks, progression, rubrics, entitlements, and reconciliation.
- Firebase Emulator tests for Security Rules, trusted functions, friendships, leagues, blocks, and subscription records.
- StoreKit Test for trials, renewals, cancellations, pending purchases, refunds, expiration, and restoration.
- Fixed AI evaluation suites for schema validity, scoring consistency, policy, and tone separation.
- UI automation for onboarding, every lesson type, offline recovery, purchases, deletion, blocking, and core accessibility.
- Content schema validation and broken-asset checks in publishing workflows.

### Manual

- Curriculum, factual, rubric, media, and accessibility review for every lesson.
- Device testing across supported iPhone sizes and supported iOS versions.
- Network conditioning, airplane mode, backgrounding, termination, storage pressure, and clock-change tests.
- Purchase review in sandbox and TestFlight.
- Moderation, reporting, blocking, and support escalation drills.

## 30. Release gates

### Internal alpha

- All P0 skeleton flows operate end to end.
- No known progress-loss or duplicate-reward defect.
- Security Rules deny unauthorized protected writes.
- AI structured evaluation passes the fixed validation suite.

### Closed TestFlight

- Complete launch curriculum subset supports end-to-end learning.
- StoreKit sandbox matrix passes.
- Critical accessibility flows pass.
- Privacy policy, terms, and support processes are operational.
- Zero open critical security, safety, purchase, or data-loss defects.

### Expanded TestFlight

- Analytics funnels and quality dashboards are validated.
- Crash-free sessions meet or approach 99.8%.
- AI visible failure rate is below 2% or has an approved remediation plan.
- Content operations demonstrate publish and rollback.
- Support can resolve login, entitlement, deletion, and moderation cases.

### App Store submission

- 99.8% crash-free sessions.
- No unresolved critical security, purchase, progress-loss, child-safety, or accessibility defects.
- Privacy labels and account deletion are complete.
- Subscription products, terms, restore flow, and reviewer notes are complete.
- Reviewer demo account and representative content are available.
- App Review can reach subscription and account-management flows.
- Production monitoring, rollback, and incident ownership are assigned.

## 31. Timeline and phasing

There is no calendar deadline. Progress is controlled by quality gates.

Suggested build sequence:

1. Foundation: Xcode project, Firebase environments, design system, navigation, authentication, CI.
2. Curriculum platform: schema, admin portal, publishing, asset pipeline, content cache.
3. Core learning: programs, modules, lesson formats, progress, offline queue.
4. AI coach: scoring service, structured feedback, revision, safety, evaluation suite.
5. Engagement: Today, mastery, XP, streaks, quests, achievements, projects.
6. Monetization: daily limit, StoreKit, entitlement sync, paywall, restoration.
7. Practice and social: review queue, leagues, friends, shared challenges, safety.
8. Profile and operations: certificates, settings, privacy, support, analytics.
9. TestFlight hardening and App Store preparation.

## 32. Change control

After written approval, this PRD is the release source of truth.

- Scope additions require a PRD revision.
- Every addition must identify a removed requirement, changed release gate, or accepted schedule impact.
- P0 requirements may not be silently downgraded.
- Pricing, daily lesson limits, target age, supported platforms, curriculum paths, social capabilities, and data practices require explicit product approval.
- Technical implementation may evolve without PRD revision when user behavior, acceptance criteria, privacy, safety, and release scope remain unchanged.

## 33. Open questions

No blocking product-scope questions remain. The following implementation decisions must be recorded before their stated gate:

| Decision | Owner | Blocking gate |
| --- | --- | --- |
| Minimum supported iOS version after current SDK and device-market review | Engineering | Xcode project configuration |
| Production AI model and fallback model, selected through the evaluation suite | Engineering, Product, Safety | AI coach implementation |
| Exact prompt, attempt, diagnostic, and account-deletion retention periods | Legal, Privacy, Engineering | Closed TestFlight |
| TestFlight cohort sizes and minimum observation periods for each quality gate | Product, Data, Engineering | Expanded TestFlight |

Localized subscription pricing is not an open product decision. StoreKit supplies the price and currency displayed for each storefront.

# Syntholo Phase 2 Curriculum Platform Implementation Plan

> **For agentic workers:** Execute this plan in order and track progress with the checkboxes. Start each behavior with a failing automated test where technically feasible. Do not begin Phase 3 attempts, scoring, allowance, progress, or lesson-completion work inside this phase.

**Created:** August 30, 2026

**Status:** Implementation-ready through synthetic tooling; original content and staging work remain blocked by the Product Bible specialization decision

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Parent plan:** `docs/superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md`

**Phase outcome:** After Product records the launch specialization required by the Product Bible, an authorized operator can validate, publish, and roll back an immutable AI Foundations fixture, while the iPhone app resolves the exact published catalog and content versions, validates them, caches the last compatible graph, renders the catalog/program/module/read-only lesson preview, and opens that preview directly from onboarding.

## 1. Product contract

This phase implements the following binding requirements:

- `LAW-1` and `LAW-2`: curriculum teaches durable skill and every complete lesson includes learner action.
- `LAW-3` and `LAW-7`: rubric identity is stable and remote curriculum cannot weaken rubric integrity.
- `LAW-11`: expected sync, cache, auth, and network failures do not erase a valid local content snapshot or lose the learner's place.
- `LAW-12`: no Firebase service credential or admin token enters the app, client source, fixture, logs, or Git history.
- `LAW-16`: fixed interface copy stays in the String Catalog and the content schema remains localization-ready.
- `LAW-18`: tests precede behavior; loading, empty, error, offline, retry, incompatible, and accessibility states ship with the happy path.
- `LAW-19`: analytics never contain lesson body text, questions, answers, prompts, learner submissions, email, or private profile text.
- `LAW-20`: all editorial copy and diagrams are original Syntholo content.
- `DEC-1`, `DEC-2`, `DEC-17`, `DEC-18`, `DEC-19`, `DEC-21`, and `DEC-22`: iOS 17, iPhone, SwiftUI/Observation/typed `NavigationStack`, Firebase, XcodeGen, minimum target sizes, and strict concurrency remain binding.
- `SHIP-FIRST-LESSON`: this phase establishes the exact-version navigation seam and opens a read-only first-lesson preview in the same session without catalog, paywall, notifications, or social interruption. Phase 3 must implement lesson start, interaction, feedback, completion, and progress before this SHIP requirement is complete.
- `SHIP-FOUNDATIONS`: this phase establishes the schema and first fixture seam for the later 3-module/12-lesson/capstone production load.
- `SHIP-ONE-PATH`: the schema supports the eventual 2-module/8-lesson selected specialization, but this phase does not choose or author it.
- `SHIP-SHELLS`: the schema supports honest `comingSoon` catalog records without fake lesson versions.
- `SHIP-VERSIONS`: published lesson and rubric versions are immutable and historical references remain resolvable.
- `SHIP-PUBLISH`: a private constrained operator path supports draft, validation, publish, and rollback. Unversioned JSON is never bundled into the learner app.
- `SHIP-FORMATS`: the versioned block contract proves the concept, still-diagram, and deterministic single-answer subset in Phase 2; Phase 3 must add the remaining required interactive, feedback, revision, results, and media behavior before this ship requirement is complete.
- `SHIP-OBJECTIVE`: the schema freezes the deterministic single-answer/on-device scoring seam; Phase 3 owns response capture, scoring execution, and queued progress.
- `SHIP-PLAYER`: the content contract includes version, objective, expected duration, and completion rule even though the interactive player arrives in Phase 3.
- `SHIP-ANALYTICS`: program, module, and lesson view events use stable, versioned, privacy-safe properties.
- `GATE-ALPHA`: this phase contributes a published Foundations sample and protected content reads; Phase 3 and Phase 4 complete the rest of that gate.

### Required product decision

- [ ] Before any original learner-facing curriculum draft is authored or loaded, before any staging or production Firestore content write, and before any staging-device content load, record the chosen deep launch specialization in the Product Bible through its normal owner/change-control process. This honors the Bible's explicit “Phase 2 content load” blocker.
- [ ] Do not infer the choice from onboarding defaults, the online-school web product, earlier recommendations, or the fixture.
- [ ] The unresolved choice does not block plan approval, JSON Schema/validator work, publisher implementation, Rules work, Swift domain/cache/repository code, or emulator/unit tests that use clearly synthetic non-editorial fixtures under `tests/fixtures/`.
- [ ] Stop at the content-load gate in Section 8 until the Product Bible contains the decision. Do not create `content/drafts/ai-foundations-v1.json`, specialization lessons, shell records, staging content, or Phase 2 exit evidence before then.

## 2. Scope boundaries

### This phase must deliver

- A documented, versioned, platform-neutral curriculum graph.
- A checked-in authoring schema, synthetic contract fixtures, and—after the product-decision gate—one original AI Foundations draft fixture.
- Pure validation with deterministic content digests.
- A trusted Node operator tool using Firebase Admin SDK and application-default credentials.
- Create-only immutable version publication, an atomic live pointer, rollback, and audit history.
- Firestore Rules that allow authenticated learners to read valid published curriculum and deny every direct curriculum write.
- A Swift domain model and testable repository boundary.
- A graph-validating Firestore adapter that loads a locale-addressed catalog through exact document gets.
- An app-owned, environment-isolated, atomically written last-compatible cache.
- Learn catalog, program detail, module detail, and read-only lesson preview.
- A typed first-lesson preview route prepared before onboarding transitions to the signed-in shell; Phase 3 owns the actual lesson-start mutation.
- Safe analytics, localized static copy, accessibility coverage, and Phase 2 evidence.

### This phase must not deliver

- Lesson attempts, lesson starts, completion, progress, mastery, XP, streaks, rewards, or daily allowance.
- Objective scoring or AI scoring.
- AI coach calls, revisions, follow-ups, moderation, or OpenAI configuration.
- StoreKit, downloads, social, notifications, or paywalls.
- A general production authoring UI.
- Draft scheduling, archive, or deprecation workflows from the north-star admin portal.
- Full Foundations or specialization editorial load.
- Runtime dependence on the sibling Neon/Postgres school application.
- An unversioned JSON file embedded in the iOS app as production curriculum.

The existing `../syntholo-main/apps/admin` content editor is not a Phase 2 backend. It uses Neon/Postgres and currently mutates published lesson records in place. It may later become a user interface over the contract in this plan only after it uses trusted Firebase Admin operations, preserves immutable versions, re-checks staff authorization, and writes the required audit trail. Until then, the constrained operator tool is the binding private publish path.

## 3. Current-state seams to preserve

- Domain models and protocols belong under `Syntholo/Services/<Area>/`.
- Firebase implementations belong under `Syntholo/Infrastructure/Firebase/` and hide SDK types behind narrow test seams.
- Main-actor view state uses `@Observable`; a view that owns such state uses `@State private`.
- `project.yml` recursively includes `Syntholo`, `SyntholoTests`, and `SyntholoUITests`; it is authoritative and `Syntholo.xcodeproj` remains generated and ignored.
- Production composition occurs in `Syntholo/App/RootView.swift`; UI test launch arguments replace live services with deterministic fixtures.
- The canonical gate is `./scripts/test.sh`, currently split into unit, functional UI, shell accessibility, onboarding accessibility, and Firestore Rules groups.
- Exact test totals are asserted in `scripts/test.sh` and `scripts/test_firebase_rules.sh`; every new test must update the corresponding expected count to the observed complete total.
- CI must stay green on the current simulator and the iOS 17.5 job in `.github/workflows/ios.yml`.

## 4. Frozen Phase 2 data contract

`content/schema/curriculum-v1.schema.json` is the normative machine-readable form of this section. Node, Firestore-shape conversion, Swift decoding, cache validation, and fixtures must use the same names, enums, bounds, and required fields. Firestore Rules enforce the exact shallow subset frozen in Section 4.9; they are not a second recursive JSON Schema engine. A code implementation may not widen either contract without a schema-version change and compatibility tests.

### 4.1 Exact limits

The following constants are binding for schema version 1:

| Value | Bound |
| --- | --- |
| Stable ID | lowercase ASCII kebab case, `^[a-z0-9]+(?:-[a-z0-9]+)*$`, 3–64 characters |
| Version | integer 1–2,147,483,647 |
| Version-document ID | at most 114 characters (the maximum stable ID, locale, delimiters, and 10-digit version all fit) |
| Locale | canonical IETF BCP 47 string, at most 35 characters; launch content is exactly `en-US` |
| SHA-256 digest | exactly 64 lowercase hexadecimal characters |
| Title / heading | 1–120 Unicode scalar values |
| Promise / summary / objective | 1–500 Unicode scalar values |
| Concept body | 1–4,000 Unicode scalar values |
| Question prompt / option / feedback | respectively 1–1,000 / 1–300 / 1–1,000 Unicode scalar values |
| Criterion description | 1–1,000 Unicode scalar values |
| Diagram node / connector label | respectively 1–120 / 1–120 Unicode scalar values; a connector label may be null |
| Accessibility description | 1–1,000 Unicode scalar values |
| Creator / license | 1–120 Unicode scalar values when present |
| Catalog programs | 1–5 `CatalogProgramEntryV1` values with unique pointer IDs and unique exact version IDs |
| Draft top-level arrays | 1–5 programs, 0–48 modules, and 0–128 each lessons/rubrics/evaluation contracts/assets, additionally subject to the publication-wide limit |
| Available program modules | 1–24 unique module-version IDs; `comingSoon` has 0 |
| Module lessons | 1–64 unique lesson-version IDs |
| Lesson prerequisites | 0–16 unique stable lesson IDs |
| Lesson blocks | 1–40 unique block IDs |
| Question options | 2–8 unique option IDs |
| Completion required blocks | 1–20 unique block IDs |
| Rubric criteria | 1–12 unique criterion IDs |
| Diagram nodes / connectors | 1–12 / 0–24, all references resolvable |
| Diagram payload | 1–131,072 canonical UTF-8 bytes; declared `byteCount` must equal the payload byte count |
| Expected duration | integer 1–180 minutes |
| Immutable Firestore document | canonical JSON at most 262,144 bytes before `publishedAt` |
| One atomic publication | at most 180 immutable documents, at most 8 MiB canonical document bytes, and at most 450 calculated Firestore writes/field transforms including version heads, pointers, and audit |

All arrays reject duplicates. All objects set `additionalProperties: false`. Strings must be valid UTF-8, NFC-normalized, and free of ASCII control characters other than permitted JSON whitespace. Numbers in curriculum v1 are integers only. `publishedAt`, `updatedAt`, and `occurredAt` are server-authored Firestore Timestamp values, never client/source strings or numeric epochs.

The pure validator applies a conservative first-publication budget without reading Firestore. Let `N` be every immutable document in the self-contained source (catalog, program, module, lesson, rubric, evaluation contract, and asset), and let `P` be the catalog program-entry count. The source requires one distinct version-head mutation per immutable document. It also requires one catalog pointer, `P` program pointers, one configuration mutation, and one audit create. Therefore document writes are `N + N + P + 3`; each has exactly one server timestamp transform, so calculated units are `2 × (2N + P + 3)`, equivalently `4N + 2P + 6`. A source above 450 units is rejected before Firebase construction even if an eventual transaction could reuse existing immutable documents or heads. The transaction path recalculates its actual writes and transforms from reads, uses the same one-unit-per-document-write and one-unit-per-server-timestamp definition, and may be lower but never higher than 450. The 180-document and 8 MiB limits remain independent. Canonical-byte limits sum final immutable shapes including generated `contentDigest` and excluding server-authored `publishedAt`.

### 4.2 Identity, locale, and compatibility

- Stable identity is never a collection index or mutable title.
- A program/module/lesson/rubric/evaluation-contract/asset stable ID is globally unique within its collection and locale; ownership fields do not namespace a reused ID.
- A locale token is the lowercase locale with hyphens preserved, for example `en-US` → `en-us`.
- A stable locale pointer ID is `<stableID>--<localeToken>`, for example `ai-foundations--en-us`.
- An immutable version ID is `<stableID>--<localeToken>--v<version>`, for example `clear-requests--en-us--v1`.
- Catalog version IDs use `catalog--<localeToken>--v<version>`.
- A new edit creates a new positive version. It never overwrites an existing version.
- A compatible same-ID/same-digest document is byte-equivalent content and may be treated as already created; same-ID/different-digest is always fatal.
- Array position expresses presentation order, but references use stable or version IDs. SwiftUI identity uses the reference, never `.indices`, `\.offset`, or a title.
- Every learner-facing immutable document contains `locale`, `schemaVersion`, and `minimumClientSchemaVersion`.
- `CurriculumSchema.currentVersion` begins at `1`. The client accepts a graph only when every learner-readable immutable document has `schemaVersion == 1` and `minimumClientSchemaVersion <= CurriculumSchema.currentVersion`.
- Unknown discriminators, invalid bounds, or broken references are malformed content, never empty content.
- The app never silently substitutes a newer content, asset, lesson, or rubric version.

The locale-addressed catalog and program pointers allow multiple locales to be live simultaneously without changing stable entity identity. Phase 2 publishes only `en-US` after the product-decision gate.

### 4.3 Canonical JSON and digests

- Canonical bytes use RFC 8785 JSON Canonicalization Scheme (JCS), UTF-8, after NFC validation. Curriculum v1 forbids non-integer numbers, avoiding cross-runtime floating-point ambiguity.
- A document `contentDigest` is lowercase hexadecimal SHA-256 over the exact final Firestore document shape with `contentDigest` and `publishedAt` omitted. IDs, locale, schema fields, ordering arrays, rights metadata, and all content remain included.
- An asset's `payloadDigest` is lowercase hexadecimal SHA-256 over only its canonical `payload`; the containing asset document still receives its own `contentDigest`.
- A `publicationDigest` is SHA-256 over a canonical object whose keys are sorted full immutable version-document paths and whose values are their `contentDigest` strings. Mutable configuration, version heads, pointers, and audit documents are not inputs.
- Node computes Firestore shapes and golden digests before writing. Swift removes exactly `contentDigest` and `publishedAt`, canonicalizes the remaining decoded document, and compares the digest before accepting it.
- `content/schema/curriculum-v1.digest-vectors.json` contains shared ASCII, Unicode, nested-object, array-order, null, and omission vectors. Both Node and Swift tests must consume the same vectors.

### 4.4 Authoring envelope and publication state

A JSON draft is one object with exactly:

- `publicationState: "draft"`.
- `schemaVersion: 1`, `minimumClientSchemaVersion: 1`, and `locale: "en-US"` for launch.
- `catalogVersion`, one catalog-version draft object.
- `programVersions`, `moduleVersions`, `lessonVersions`, `rubricVersions`, `evaluationContractVersions`, and `assetVersions`, each a bounded array of the corresponding draft shape.

Every nested draft version contains exactly the corresponding immutable shape in Sections 4.6–4.7 with `publicationState: "draft"`, except generated `contentDigest` and `publishedAt` are absent. Each non-catalog version explicitly contains its stable ID, version ID, positive `version`, locale, and schema fields; the catalog contains its catalog version ID/version/locale/schema fields and exact ordered program entries. Asset drafts additionally omit generated `byteCount` and `payloadDigest`. The deterministic transform verifies that every supplied version ID matches its stable ID/locale/version (or catalog locale/version), changes nested state to `published`, computes asset bytes/digests and document/publication digests, and lets the server transaction add timestamps.

Mutable pointer/configuration documents are not authorable draft fields. The transform derives only their already-frozen fields: the locale catalog pointer and its minimum-client value from the catalog locale/version, one program pointer per catalog entry from its exact IDs, and the `en-US` feature-configuration entry from the same locale pointer. The source contains no timestamps. No immutable authored content field is generated or defaulted, and no pointer/configuration value may be supplied out of band.

Drafts exist only under `content/drafts/` after the product-decision gate. Synthetic non-editorial contract fixtures use `tests/fixtures/content/` and may never be passed to a non-emulator publisher. The reserved exact string `SYNTHETIC-CONTRACT-FIXTURE-NEVER-PUBLISH` must appear in every synthetic fixture's learner-visible title and must never appear in editorial content. A source is classified as synthetic when either its resolved real path is under `tests/fixtures/content/` or any string value in the envelope equals that sentinel; copying or renaming the fixture therefore cannot remove the restriction. Pure validation accepts a synthetic source, but publish-context validation accepts it only for the exact emulator tuple `environment: emulator`, `projectID: syntholo-local`, `credentialPrincipal: emulator-local`, with a non-empty `FIRESTORE_EMULATOR_HOST`. No draft or `publicationState != "published"` document enters a learner-readable collection.

The envelope is self-contained: its arrays contain exactly every program/module/lesson/rubric/evaluation-contract/asset version reachable from `catalogVersion.programEntries`, including unchanged versions intended for reuse, and contain no orphan. Pure validation never consults Firestore. Publication may reuse an included version already stored only after exact ID/digest/shape equality succeeds.

### 4.5 Exact schema-v1 nested types

`CompletionRuleV1` has exactly:

- `kind: "requiredBlocksCorrect"`.
- `requiredBlockIDs`, 1–20 unique IDs of scorable question blocks present in the same lesson.
- `minimumCorrectCount`, integer from 1 through `requiredBlockIDs.count`.
- `allowsRevision: bool`.

`ContentBlockV1` is a closed discriminated union:

- `conceptText`: `blockID`, `type`, `order`, optional `heading`, and `body`.
- `stillDiagram`: `blockID`, `type`, `order`, `title`, and exact `assetVersionID`; the asset must be `diagramData` and carry its text alternative.
- `singleAnswerQuestion`: `blockID`, `type`, `order`, `prompt`, and `options`. Each option has exactly stable `optionID` and `text`.

Block `order` values are unique consecutive integers starting at 0 and must match array order. An available schema-v1 lesson contains exactly one `singleAnswerQuestion`; its completion rule contains exactly that block ID and `minimumCorrectCount == 1`. Schema v1 supports no other block. Phase 3 adds remaining `SHIP-FORMATS` through a compatible schema extension/version; its publication must first raise the backward-readable configuration header so an older client enters update-required before fetching the new block. If an unknown block bypasses that header invariant, the client fails closed as unavailable rather than ignoring it.

`CriterionV1` has exactly stable `criterionID`, `title` (the title bound in Section 4.1), `description` (the criterion-description bound in Section 4.1), and integer `maxScore` from 1–100.

`ClientScoringContractV1` has exactly `kind: "singleAnswer"`, `questionBlockID`, `correctOptionID`, `correctFeedback`, and `incorrectFeedback`. It is downloaded for deterministic on-device feedback and is therefore **not a secret or security boundary**. The UI and analytics must not display/log the answer key, but authoritative progress/reward code must independently re-evaluate against the protected evaluation contract in Phase 3.

`DiagramAssetPayloadV1` has exactly ordered `nodes` and `connectors`. A node has stable `nodeID`, bounded `label`, and `emphasis` (`normal` or `accent`). A connector has stable `connectorID`, exact `fromNodeID`, exact `toNodeID`, and nullable bounded `label`; self-links and broken links fail. Omission and `null` are not interchangeable: every connector contains `label`, using `null` when absent.

`RightsMetadataV1` has exactly `origin` (`original` or `licensed`), `creator`, nullable `sourceURL`, and nullable `license`. `sourceURL` is an HTTPS URL of at most 2,048 characters when present. Original Syntholo diagrams use `origin: "original"`; licensed content requires non-null source and license.

### 4.6 Learner-readable Firestore documents

All client reads are authenticated exact-document gets rooted in a locale catalog. There is no broad curriculum collection query in schema v1.

#### `catalogs/{localeToken}` — stable mutable locale pointer

The document ID is exactly the locale token. Fields are exactly `locale`, `publishedCatalogVersionID`, `schemaVersion: 1`, positive integer `minimumClientSchemaVersion`, and server `updatedAt`. This pointer is also a backward-readable compatibility header and its minimum equals the selected immutable catalog version's minimum. Only the trusted publisher may change the version ID/minimum/timestamp.

#### `catalogVersions/{catalogVersionID}` — immutable

Exactly: `catalogVersionID`, `version`, `locale`, `publicationState: "published"`, `schemaVersion`, `minimumClientSchemaVersion`, ordered unique `programEntries`, `contentDigest`, and server `publishedAt`.

`CatalogProgramEntryV1` has exactly `programPointerID` and `programVersionID`. The pointer ID uses `<programID>--<localeToken>` and the version ID uses `<programID>--<localeToken>--v<version>` for that same program and locale. Both fields are unique across the array. The immutable entry pins the exact program version; the learner never resolves catalog content through the mutable program pointer.

#### `programs/{programPointerID}` — stable mutable locale pointer

Exactly: `programPointerID` equal to document ID, stable `programID`, `locale`, `publishedVersionID`, `schemaVersion: 1`, and server `updatedAt`. Only the trusted publisher may change the version ID/timestamp.

#### `programVersions/{programVersionID}` — immutable

Exactly: `programVersionID`, stable `programID`, `version`, `locale`, `publicationState`, `title`, `promise`, `catalogState` (`available` or `comingSoon`), `schemaVersion`, `minimumClientSchemaVersion`, ordered `moduleVersionIDs`, nullable `firstLessonVersionID`, `contentDigest`, and `publishedAt`.

An `available` program has 1–24 modules and a first lesson. A `comingSoon` program has zero modules and a null first lesson. The launch Foundations stable identity is exactly `programID: "ai-foundations"`; a Phase 2 launch catalog contains exactly one available `ai-foundations` entry. Shell records may be authored only after Product records the launch specialization.

#### `modules/{moduleVersionID}` — immutable

Exactly: `moduleVersionID`, stable `moduleID`, stable `programID`, `version`, `locale`, `publicationState`, `title`, `summary`, `schemaVersion`, `minimumClientSchemaVersion`, ordered `lessonVersionIDs`, `contentDigest`, and `publishedAt`. A module version may be reused by a later program version when its exact digest and program ownership are unchanged.

#### `lessonVersions/{lessonVersionID}` — immutable

Exactly: `lessonVersionID`, stable `lessonID`, stable `programID`, stable `moduleID`, `version`, `locale`, `publicationState`, `title`, `objective`, `expectedDurationMinutes`, ordered stable `prerequisiteLessonIDs`, `completionRule`, ordered `blocks`, exact `rubricVersionID`, ordered `assetVersionIDs`, `schemaVersion`, `minimumClientSchemaVersion`, `contentDigest`, and `publishedAt`.

Prerequisites use stable lesson IDs—not versions—so an acknowledged completion is not invalidated by a later editorial version. Phase 3 owns completion reconciliation; Phase 2 validates only the prerequisite DAG and reachability.

#### `rubricVersions/{rubricVersionID}` — immutable and learner-readable

Exactly: `rubricVersionID`, stable `rubricID`, `version`, `locale`, `publicationState`, `kind: "deterministic"`, `criteria`, non-null `clientScoringContract`, exact `evaluationContractVersionID`, `schemaVersion`, `minimumClientSchemaVersion`, `contentDigest`, and `publishedAt`.

Schema v1 supports only the deterministic single-answer rubric required by its lesson/completion contract. A later criterion/AI rubric requires a schema extension that freezes its evaluation and completion semantics. Criteria and client scoring data are presentation/client behavior, not the protected authoritative evaluation source.

#### `assetVersions/{assetVersionID}` — immutable

Schema v1 supports exactly: `assetVersionID`, stable `assetID`, `version`, `locale`, `publicationState`, `kind: "diagramData"`, `mimeType: "application/vnd.syntholo.diagram+json"`, integer `byteCount`, `payloadDigest`, `payload: DiagramAssetPayloadV1`, `accessibilityDescription`, `rights: RightsMetadataV1`, `schemaVersion`, `minimumClientSchemaVersion`, `contentDigest`, and `publishedAt`.

Later video/image/caption/transcript assets require a schema extension with immutable Storage path, MIME type, size, digest, captions/transcript, and rights fields. Storage blobs are never placed in Firestore.

#### `featureConfiguration/curriculum` — constrained mutable configuration

Exactly: `schemaVersion: 1`, positive integer `minimumClientSchemaVersion`, `defaultLocale: "en-US"`, ordered unique `supportedLocales` (1–10), ordered matching `catalogPointerIDs`, and server `updatedAt`. At each array index the pointer ID is exactly that locale's lowercase locale token and resolves `catalogs/{localeToken}`. This fixed schema-v1 document is the backward-readable compatibility header: a future content-schema publication must atomically raise `minimumClientSchemaVersion` before an older client can fetch an unsupported immutable document, and future configuration adds separate documents rather than new keys here. It may locate catalogs only. It cannot select rubrics, change age/safety/entitlement rules, or lower `minimumClientSchemaVersion`.

The Phase 2 deployed value additionally has `minimumClientSchemaVersion: 1`, `supportedLocales: ["en-US"]`, and `catalogPointerIDs: ["en-us"]`. Adding another locale requires later reviewed content and configuration; the arrays exist now only to freeze the compatible extension shape.

### 4.7 Trusted-private Firestore documents

#### `evaluationContractVersions/{evaluationContractVersionID}` — immutable, server-only

Exactly: `evaluationContractVersionID`, stable `evaluationContractID`, exact `rubricVersionID`, `version`, `locale`, `publicationState`, `kind: "singleAnswer"`, `questionBlockID`, `correctOptionID`, `schemaVersion`, `contentDigest`, and `publishedAt`. Learner clients cannot read or write this collection. Publisher validation requires the public client contract and protected contract to agree; Phase 3 server logic treats only this protected copy as authoritative.

#### `contentVersionHeads/{versionHeadID}` — mutable, server-only

The ID is exactly `<kind>--<stableID>--<localeToken>` and at most 128 characters. `kind` is one of `catalog`, `program`, `module`, `lesson`, `rubric`, `evaluation-contract`, or `asset`; catalog uses stable ID `catalog`. Fields are exactly `versionHeadID`, `kind`, `stableID`, `locale`, positive integer `maxPublishedVersion`, `schemaVersion: 1`, and server `updatedAt`. The publisher exact-gets and atomically advances these heads whenever it creates a new immutable version. Rollback never lowers them. This is the authoritative concurrency-safe historical maximum; publisher code does not infer monotonicity from the mutable live pointer.

#### `contentPublicationAudit/{operationID}` — immutable, server-only

Every operation is locale-catalog-rooted. The audit document has exactly: `schemaVersion: 1`, `operationID` (caller-generated canonical lowercase RFC 4122 UUID string, 36 characters), `requestDigest`, `action` (`publish` or `rollback`), `outcome` (`applied` or `noOp`), `environment` (`emulator`, `staging`, or `production`), actual non-empty `projectID`/`projectNumber` (at most 120 characters each), derived non-empty `credentialPrincipal` (at most 320 characters), nullable `requestedBy` (at most 320 characters), exact `catalogPointerID`, nullable `fromCatalogVersionID`, exact `toCatalogVersionID`, ordered `programSelections`, `publicationDigest`, and server `occurredAt`.

`ProgramSelectionV1` has exactly `programPointerID`, nullable `fromProgramVersionID`, and exact `toProgramVersionID`; its array order matches the target catalog's `programEntries` and contains 1–5 unique pointer IDs. It records the prior and target selection even when they are equal. `requestDigest` is SHA-256 over the RFC 8785 canonical object containing exactly `schemaVersion: 1`, `action`, `environment`, `projectID`, `projectNumber`, `credentialPrincipal`, `requestedBy`, `catalogPointerID`, `toCatalogVersionID`, and `publicationDigest`. It excludes the operation ID, prior state, outcome, and timestamp. The authenticated principal is derived from the approved workload/user credential; `requestedBy` is descriptive and cannot authorize or impersonate an actor.

### 4.8 Graph invariants

Publication and Node tests reject the full operation unless every invariant below holds. Swift rejects a learner-readable snapshot unless every invariant derivable from learner-readable documents holds; it does not fetch or pretend to validate the protected evaluation agreement, authoring-envelope reachability, credential scan, or transaction budget.

- The locale catalog pointer resolves to one exact immutable catalog version with matching locale and compatibility.
- Every ordered catalog entry pins one exact same-locale published program version. Its program pointer ID and program version ID encode the same stable program ID, but client graph resolution never dereferences the mutable program pointer.
- Every immutable document has `publicationState == "published"`, matching locale, compatible schema fields, valid canonical bytes, and a matching digest.
- Each program references only same-program module versions; each module references only same-program/module lesson versions.
- Every lesson rubric and asset reference resolves exactly; every block-level asset appears in `assetVersionIDs` and no unused asset reference is present.
- Within one snapshot, each stable catalog/program/module/lesson/rubric/asset identity resolves to at most one version.
- Ordered reference arrays and stable IDs contain no duplicates.
- Prerequisite stable IDs resolve within the same available program, form a directed acyclic graph, and are reachable in catalog order; the first lesson has no prerequisite.
- The catalog contains exactly one available `ai-foundations` program; its `firstLessonVersionID` resolves to that program's first eligible lesson without catalog browsing.
- `comingSoon` program versions contain no module, lesson, rubric, or asset references.
- Completion-rule block IDs resolve and the public question/answer IDs resolve. Publisher-only validation proves the protected evaluation contract matches the public deterministic client contract at publication time.
- Every available Phase 2 lesson contains at least one concept block, one meaningful diagram with a non-empty text alternative, and one deterministic question required by its completion rule. Editorial review additionally proves the question is an applied realistic check under `LAW-2`.
- Publisher-only validation proves every catalog/program/module/lesson/rubric/evaluation-contract/asset version supplied by the operation is reachable from the target catalog graph; orphan payloads and undeclared dependencies fail validation.
- Publisher-only validation proves no field contains a credential or forbidden private fixture data.
- Publisher-only validation proves the calculated transaction remains within the exact document, byte, and write/transform limits in Section 4.1.

### 4.9 Exact Firestore Rules boundary

Firestore Rules enforce only the subset they can prove locally for one requested document:

- Authenticated exact `get` only and no `list` for `featureConfiguration/curriculum`, locale catalog/program pointers, and the learner-readable immutable collections. An authenticated exact get of a missing allowed-path document is permitted to return not-found; Rules must not turn absence into permission-denied by dereferencing missing `resource.data`.
- When the requested document exists, its ID equals its corresponding ID field (or locale token for `catalogs`), top-level keys are exactly allowlisted, required top-level values have the expected primitive/map/list types, `publicationState == "published"` where applicable, schema values are integers with `schemaVersion == 1`, simple string/list bounds are respected, and configured reference lists do not exceed Section 4.1 limits.
- All client create, update, and delete operations in every curriculum/configuration/private/authoring collection are denied.
- Every read and write of version heads, evaluation contracts, publication audits, and authoring namespaces is denied.

Rules do **not** claim to recursively prove the content-block union, nested option/node/connector shapes, uniqueness, ordering, cross-document references, DAG reachability, canonicalization, SHA-256 digests, or publication transaction integrity. The trusted Node path proves all of those before writing, and Swift proves every learner-relevant invariant again before rendering or replacing cache. A nested malformed document may pass the shallow read rule but must be rejected by Swift; because clients cannot write it, this does not widen publication authority.

## 5. Publication and rollback contract

### 5.1 Draft and validation

1. Before the product-decision gate, tests use only synthetic non-editorial JSON under `tests/fixtures/content/` and publishers accept it only when `FIRESTORE_EMULATOR_HOST` is set and the approved environment entry is `emulator`.
2. After Product records the decision, authors may edit an original, version-controlled JSON draft under `content/drafts/`.
3. `content:validate` validates the normative JSON Schema, exact bounds, canonicalization vectors, graph/DAG invariants, public/protected scoring agreement, locale, accessibility, rights metadata, transaction budget, and deterministic digests without writing.
4. `content:publish --dry-run` is the constrained structural preview: it prints only environment, project, derived credential principal, requested-by value, operation ID, IDs/counts/digests, pointer changes, and audit action. It never prints lesson bodies, question options, feedback, or evaluation contracts.
5. `content/config/environments.json` is a checked-in, non-secret object with exactly `schemaVersion: 1` and `environments` (1–3 entries with unique environment/project ID/project number). Each entry contains exactly `environment`, `projectID`, `projectNumber`, `publicationMode`, and 1–10 unique approved `credentialPrincipals`; `environment` and `publicationMode` are the same literal from `emulator`, `staging`, or `production`. A live project ID matches `^[a-z][a-z0-9-]{4,28}[a-z0-9]$`; a live project number matches `^[0-9]{6,20}$`; each live principal is an exact service-account email ending `@<projectID>.iam.gserviceaccount.com`. The emulator entry alone uses `projectID: "syntholo-local"`, `projectNumber: "emulator"`, and principal `emulator-local`; live values must be supplied by the environment owner and are never invented by this plan. Development has no content-publication entry in Phase 2 and is rejected.
6. Non-emulator publication additionally requires a tracked `content/config/launch-content-decision.json` citing the dated Product Bible decision and containing the selected specialization enum. This derivative gate file is not authority; mismatch with the Bible is fatal.
7. Live Phase 2 publication accepts only keyless ADC that impersonates an allowlisted least-privilege publisher service account; direct user ADC, service-account key JSON, refresh-token files copied into the repository, and a caller-supplied principal are rejected. The tool derives the target service-account email from the impersonated credential metadata, resolves the actual project ID/number through authenticated Google project metadata, and compares requested environment/project/confirmation, actual project ID/number, and derived principal to the allowlist before Firestore construction. Passing a production project as `staging` cannot bypass production safeguards. Cloud audit logging remains the authoritative record of the underlying user/workload that impersonated the publisher account.
8. Phase 2 permits staging writes only. Production publication remains disabled until the launch-content load and later production gates explicitly authorize it.
9. No draft or synthetic fixture is copied into `Syntholo/` or bundled by XcodeGen.

### 5.2 Publish transaction

1. One publish command is exactly one locale-catalog-rooted operation. Its self-contained source contains one catalog version plus the complete graph for the ordered set of 1–5 program versions selected by that catalog; it may create/update multiple program pointers atomically. Require explicit `--operation-id <uuid>`, `--environment`, `--project`, `--confirm-project`, and source. `--requested-by` is optional descriptive text and never authorizes the write. There is no program-only publish mode.
2. When `FIRESTORE_EMULATOR_HOST` is set and the allowlisted emulator entry matches, use only the fixed `emulator-local` principal and never request live ADC. Otherwise authenticate through ADC/IAM, derive the actual credential principal/project, and apply all Section 5.1 gates. Never accept service-account JSON through source or command-line text.
3. Compute the exact `requestDigest`. If `contentPublicationAudit/{operationID}` exists and its request digest plus every stored request field match, return its recorded `outcome` as an idempotent replay without evaluating current live state. If any field differs, abort as an operation-ID collision.
4. Before any write, exact-get the locale catalog pointer/current catalog, every target program pointer, every exact target document ID, and the corresponding private version head for each catalog/program/module/lesson/rubric/evaluation-contract/asset identity represented by the source.
5. A missing target catalog version is a normal rollout only when its version is greater than the catalog head (or positive when neither head nor historical document exists). A missing program version that changes/adds a program selection must exceed its program head. Every other missing immutable version must likewise exceed its identity/locale head. An existing immutable document with a missing head, or a version greater than its head, is corrupt operator state and fails closed. Rollback never creates an immutable version or lowers a head.
6. An existing same-ID/same-digest subordinate document may be reused by a new graph only after its entire exact shape matches. A target catalog already live with the same digest is a no-op candidate only when every source-referenced immutable document and corresponding version head already exists and matches, and catalog/program pointers plus configuration already match it. Missing immutable data/head under a live catalog is corruption and fails closed; no-op may not repair it. A same-live catalog with drifted mutable records also fails closed and requires rollback repair. If the target catalog exists but is not live, or a target program selection would repoint a program pointer to an existing non-live version, reject with “use rollback.” A different digest at any existing version ID is fatal.
7. Re-run schema, graph, public/protected scoring, digest, locale, immutable catalog-entry, historical-version, and transaction-budget validation inside the transaction callback.
8. For an applied rollout, create missing immutable catalog/program/module/lesson/rubric/evaluation-contract/asset documents with create-only semantics and atomically create/advance their exact private version heads. For a validated no-op candidate, skip all immutable/head/pointer/configuration writes.
9. For an applied rollout, update/create the locale catalog pointer and every program pointer selected by the target catalog, plus the constrained curriculum feature configuration, with server timestamps. Program pointers are secondary current-selection records; clients resolve the snapshot through the catalog's pinned program version IDs.
10. Create `contentPublicationAudit/{operationID}` for both `applied` and `noOp` outcomes, with the derived principal, request/publication digests, catalog transition, and complete ordered program selections in the same transaction. A new no-op operation writes exactly this one audit document; an exact replay writes nothing.
11. Print only safe IDs, counts, environment/project, operation ID/outcome, and digests.

The immutable catalog pins the complete learner graph. Its documents, catalog/program pointer selections, configuration, and audit are committed in one bounded atomic transaction. A learner that captures either the previous or new catalog pointer therefore resolves one previously validated immutable snapshot, never a mix assembled from mutable program pointers.

### 5.3 Rollback transaction

1. Rollback is exactly locale-catalog-rooted; schema v1 has no program-only rollback because that could create a catalog/program combination that was never published atomically. Require a new explicit operation ID, environment/project confirmation, exact locale catalog pointer ID, and existing `--to-catalog-version`. Apply the same principal and decision gates as publish.
2. Compute the request digest. Replay an existing matching audit operation and its recorded outcome exactly without consulting changed live state; reject an operation-ID collision.
3. Load and validate the complete target catalog graph directly from its pinned same-locale program version IDs, including every immutable reference/digest, every corresponding version head at or above that version, and every target program pointer identity. Reject missing, malformed, incompatible, cross-program, cross-locale, non-catalog, or corrupt-head content.
4. If the target catalog, every target program pointer, and configuration already match under a new operation ID, create an `outcome: "noOp"` audit but perform no pointer write. This makes the accepted operation ID permanently replayable.
5. Otherwise atomically select the target locale catalog version, repair/update/create each program pointer and configuration to the exact target catalog state, and create an `outcome: "applied"` rollback audit containing the full catalog/program transition. Program pointers for programs absent from the target catalog may remain as inert secondary records because the client never uses them to resolve membership.
6. Never delete, rewrite, relabel, or create an immutable version during rollback.

## 6. Client load, cache, and error contract

### 6.1 Repository algorithm

The domain boundary is exactly:

```swift
enum CurriculumLoadEvent: Equatable, Sendable {
    case saved(CurriculumSnapshot)
    case fresh(CurriculumSnapshot)
    case empty
    case updateRequired(requiredSchema: Int, saved: CurriculumSnapshot?)
    case unavailable(error: CurriculumRepositoryError, saved: CurriculumSnapshot?)
}

protocol CurriculumRepository: Sendable {
    func load(locale: CurriculumLocale) -> AsyncStream<CurriculumLoadEvent>
}
```

One subscription performs this deterministic sequence:

1. Read and fully validate the environment/project/locale-specific cache.
2. If valid, yield exactly one `.saved(snapshot)` immediately, then continue refreshing.
3. Force a server-source exact get for the backward-readable `featureConfiguration/curriculum` header. If it exists and `minimumClientSchemaVersion` exceeds the client, stop with `.updateRequired`. Otherwise exact-get the backward-readable `catalogs/{localeToken}` pointer and repeat the minimum-client check before fetching the captured immutable catalog version. This second check closes the race where a newer publication commits between the configuration and pointer reads.
4. In catalog order, exact-get each program version pinned by `CatalogProgramEntryV1`, then exact-get its referenced modules, lessons, learner-readable rubrics, and assets. Never dereference mutable program pointers during snapshot resolution, and never fetch `evaluationContractVersions` from the client.
5. Decode into domain values without exposing Firebase SDK objects outside the adapter.
6. Validate compatibility, locale, graph/prerequisite invariants, public scoring references, canonical bytes, and every digest.
7. Atomically replace the cache only after the complete catalog graph passes, then yield `.fresh(snapshot)` and finish.
8. `.empty` has exactly two no-cache meanings: the compatibility header does not exist because no curriculum has ever been published, or the header exists but does not list the requested locale. If a valid saved snapshot was already yielded for either condition, yield `.unavailable(error: .notPublished, saved: snapshot)` so remote withdrawal cannot erase usable content. A header that lists the locale but lacks its catalog pointer, or a pointer whose immutable target is missing, is a broken publication and yields `.unavailable`, never `.empty`. Only a readable header whose `minimumClientSchemaVersion` exceeds the client yields `.updateRequired`; an unsupported schema encountered behind a supposedly compatible header is a backend-contract failure and yields `.unavailable(error: .unsupportedSchema(...), saved: ...)`. Every other remote failure also yields `.unavailable`; terminal events carry the already-yielded compatible snapshot when one exists, then finish.
9. Cancelling iteration cancels the remote task and performs no cache replacement. A later load may resolve new pointers but never mutates a snapshot value already displayed.

`CurriculumStore` owns one load task, ignores duplicate load/retry requests while it is active, cancels it on deinit/replacement, and starts a new stream only for explicit retry, refresh, locale change, or environment change.

### 6.2 Cache contract

- Cache location: Application Support under an environment/project/locale-specific directory such as `Curriculum/development/syntholo-local/en-US/catalog-snapshot-v1.json`.
- Different environments, Firebase projects, locales, and envelope versions never share a file.
- Cache envelope includes envelope version, saved timestamp, source project ID/number/environment, locale, exact catalog pointer/version, ordered catalog program entries with their pinned versions, every document digest, and the complete bounded learner-readable snapshot.
- Writes use atomic replacement.
- Reads revalidate envelope version, compatibility, graph, and digests.
- Corrupt, partial, wrong-project/environment/locale, or incompatible cache data is atomically renamed beside the cache to `catalog-snapshot-v1.invalid-<UTC-milliseconds>.json` and ignored. Failure to quarantine still returns it as invalid and never deletes the last separately valid snapshot.
- The last valid cache survives a failed remote refresh and an incompatible new publication.
- Firestore SDK caching is not the authoritative curriculum cache; the application cache owns the validated graph contract.

### 6.3 Typed internal errors and learner-visible states

Internal repository errors distinguish at least:

- `notPublished`.
- `contentUnavailable`.
- `authenticationRequired`.
- `networkUnavailable`.
- `malformedDocument(path)`.
- `brokenReference(id)`.
- `digestMismatch(id)`.
- `unsupportedSchema(found:supported:)`.
- `minimumClientUnsupported(required:supported:)`.
- `cacheCorrupt`.
- `wrongEnvironment`.
- `operationCancelled`.
- `backendFailure`.

The UI state is intentionally smaller and safe:

- `loading` — no valid content yet; show progress and a clear label.
- `ready(snapshot, freshness: fresh)` — current validated remote content.
- `ready(snapshot, freshness: saved)` — valid cache is usable; show non-color stale/saved status and retry.
- `empty` — no published locale catalog exists; never use this for a malformed or zero-entry catalog.
- `updateRequired(requiredVersion, fallbackSnapshot?)` — explain that a newer app is required; preserve compatible saved content if available.
- `unavailable(retryable: true)` — keep the learner's place and provide a 44-point retry control.

Do not expose Firestore paths, raw SDK errors, digests, public answer-key fields, protected evaluation contracts, or operator data to learners.

## 7. SwiftUI and navigation contract

- Use `@MainActor @Observable final class CurriculumStore` with an `Equatable` state enum so redundant assignments do not invalidate views.
- A view that owns the store uses `@State private`; injected observable stores are passed as read-only values unless a binding is actually required.
- Repository work begins in `.task` or explicit async actions, never in a SwiftUI view initializer or `body`.
- Use `NavigationStack(path:)`, `NavigationLink(value:)`, and `navigationDestination(for:)` with a `Hashable` `LearnRoute`.
- `LearnRoute.lesson(LessonVersionReference)` carries locale plus exact catalog/program/module/lesson/rubric version identity; it never carries an array position.
- `AppRouter` owns the Learn path and selected tab. `LearnHomeView` binds to it through `@Bindable` only where it needs the path binding.
- Program/module/lesson rows use stable entity IDs and one top-level row view. Do not use `.indices`, offsets, inline filtering, `AnyView`, or a mutable title as identity.
- Split program header, module list, content block, diagram, question preview, status, and retry UI into narrow view types; do not place decoding, filtering, or sorting in `body`.
- Use native `Button`/`NavigationLink`, `ContentUnavailableView`, `ProgressView`, system text styles, semantic color, and SF Symbols. No UIKit bridge or iOS 26-only visual API is needed.
- Keep the iOS 17-compatible tab shell. Do not adopt the iOS 18 `Tab` API or Liquid Glass in this slice.

### First-lesson handoff invariant

Phase 2 internal/staging builds label this read-only action **Preview the first lesson**. The launch label **Start the first lesson** returns only in Phase 3 when the start/attempt mutation exists. Phase 2 evidence must not claim `SHIP-FIRST-LESSON` complete.

When the learner taps **Preview the first lesson**:

1. Remain in the onboarding handoff while the exact first lesson is resolved.
2. Disable duplicate taps and expose an accessible loading state.
3. If resolution fails without a valid cache, remain on the handoff and offer retry.
4. If resolution succeeds, set `AppRouter` to Learn and append the exact typed lesson-version route.
5. Only then call `OnboardingCoordinator.completeFirstLessonHandoff()` and reveal the signed-in shell.
6. The first signed-in screen is the real immutable lesson preview, not Learn home or the catalog.
7. No paywall, notifications prompt, or social surface appears before it.

Curriculum resolution belongs in root composition/curriculum state, not inside `OnboardingCoordinator`; onboarding must not become coupled to Firestore content details.

## 8. Implementation tasks

Run all commands from the repository root.

### Task 1 — Approve the frozen contract and establish RED

**Files**

- Use: `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`
- Use: `docs/superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md`
- Modify: `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`
- Create: `tests/content/curriculum-validation.test.mjs`

- [ ] Product, curriculum, iOS, backend, privacy, and accessibility owners review Sections 4–7 without choosing a specialization in this plan.
- [x] Confirm the plan cites every required `SHIP-*`/`LAW-*` ID, including `SHIP-FORMATS`.
- [x] Write failing tests for every exact shape/bound, locale/version ID, catalog order, publication state, prerequisite DAG, asset/rights field, public/protected scoring agreement, JCS vector, document/publication digest, transaction budget, and unknown property/discriminator.
- [x] Confirm RED because the schema, vectors, validator, and synthetic fixture do not exist.
- [x] Do not create an original curriculum draft in this task.

Run:

```bash
node --test tests/content/curriculum-validation.test.mjs
for id in \
  SHIP-FOUNDATIONS SHIP-ONE-PATH SHIP-SHELLS SHIP-VERSIONS \
  SHIP-PUBLISH SHIP-FIRST-LESSON SHIP-FORMATS SHIP-OBJECTIVE \
  SHIP-PLAYER SHIP-ANALYTICS \
  LAW-1 LAW-2 LAW-3 LAW-7 LAW-11 LAW-12 LAW-16 LAW-18 LAW-19 LAW-20; do
  rg -q "$id" docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md
done
```

Expected: the Node test is RED for the intended missing implementation, while every trace assertion succeeds.

### Task 2 — Implement schema, pure validation, and deterministic shapes

**Files**

- Create: `content/schema/curriculum-v1.schema.json`
- Create: `content/schema/curriculum-v1.digest-vectors.json`
- Create: `tests/fixtures/content/minimal-curriculum-v1.json`
- Create: `tools/content/lib/canonical-json.mjs`
- Create: `tools/content/lib/curriculum-validation.mjs`
- Create: `tools/content/lib/firestore-shape.mjs`
- Create: `tools/content/validate.mjs`
- Create: `scripts/scan_secrets.sh`
- Modify: `package.json`
- Modify: `package-lock.json`
- Modify: `.github/workflows/ios.yml`
- Modify: `scripts/test.sh`
- Modify: `.gitignore` only for generated reports/quarantine—not credentials
- Modify: `docs/setup/firebase.md`

- [x] Pin direct exact development dependencies for JSON Schema validation, RFC 8785 canonicalization, and Firebase Admin SDK.
- [x] Make the synthetic fixture unmistakably non-editorial and reject it outside the emulator.
- [x] Implement validation and Firestore-shape conversion exactly from Section 4 with structured error codes and document paths.
- [x] Consume the shared digest vectors and prove array order changes the digest while object-key order does not.
- [x] Reject invalid input and transaction-budget overflow before any Firebase client is created.
- [x] Add `content:validate` and content tests to `package.json` and the canonical test path.
- [x] Implement a documented, version-pinned secret scan over working tree and full Git history, plus explicit `--generated <path>` and `--bundle <path>` targets, and run the repository scopes in CI; filename checks remain supplemental. Firebase public client configuration may be explicitly allowlisted, but credentials/tokens may not.

Run:

```bash
npm ci
npm run content:validate -- tests/fixtures/content/minimal-curriculum-v1.json
node --test tests/content/curriculum-validation.test.mjs
./scripts/scan_secrets.sh --history --worktree
git ls-files '*service-account*.json' '*GoogleService-Info.plist' '*.firebase.plist'
```

Expected: schema/negative/golden-vector tests are GREEN, invalid input writes nothing, the history/worktree scan reports no credential, and the filename command is empty.

### Task 3 — Build an idempotent emulator-only publisher and rollback tool

**Files**

- Create: `content/config/environments.json` with the emulator entry only
- Create: `content/config/launch-content-decision.schema.json`
- Create: `tools/content/lib/operator-identity.mjs`
- Create: `tools/content/publish.mjs`
- Create: `tools/content/rollback.mjs`
- Create: `tests/firebase/curriculum-publication.test.mjs`
- Create: `scripts/test_content_publication.sh`
- Modify: `package.json`
- Modify: `scripts/test.sh`
- Modify: `docs/setup/firebase.md`

- [ ] Start with failing emulator tests for first catalog-root publish, atomic version-head creation/advance, historical-max monotonicity for every immutable identity (including after rollback), missing/corrupt head failure, same-live same-digest no-op writing exactly one audit and nothing else, different-digest collision, existing non-live selection rejection, v2 roll-forward, exact catalog rollback, repeated rollback audit-without-pointer-write, operation replay after later state changes, operation collision, immutable catalog pinning, and atomic audit/pointers.
- [ ] Test disguised production-as-staging project, unknown project number, unapproved principal, synthetic fixture outside emulator, missing decision record for non-emulator, and transaction-budget rejection.
- [ ] Before importing or constructing Firebase Admin, run the pinned gitleaks policy against the exact resolved source file in addition to the repository gate; reject planted AWS access-key/secret-key shapes and every scanner finding without honoring source-local suppressions.
- [ ] Require mutually exclusive `--dry-run` or `--apply`, explicit operation ID, environment/project confirmation, and optional non-authorizing requested-by text.
- [ ] Implement create-only immutable writes, derived principal/project verification, deterministic operation replay, and the exact publish/rollback semantics in Section 5.
- [ ] Ensure every injected exception leaves the prior pointers/graph unchanged.
- [ ] Use the repository's isolated-port emulator runner; never depend on a fixed port.
- [ ] Add the publication emulator suite to `./scripts/test.sh` with an exact observed count.

Run:

```bash
./scripts/test_content_publication.sh
```

Expected: all lifecycle, authorization-gate, collision, replay, and atomicity tests pass using only the synthetic fixture and emulator.

### Task 4 — Protect exact curriculum reads with Firestore Rules

**Files**

- Modify: `firestore.rules`
- Modify: `tests/firebase/firestore.rules.test.mjs`
- Modify: `scripts/test_firebase_rules.sh`
- Review: `firestore.indexes.json`

- [ ] Add failing Rules tests first.
- [ ] Prove unauthenticated exact gets fail for configuration, catalog/program pointers, and every learner-readable immutable collection.
- [ ] Seed valid published shapes with security disabled and prove authenticated exact gets succeed only through `get`, never `list`; prove an authenticated exact get of an allowed but absent path returns not-found rather than permission-denied.
- [ ] Prove draft/non-published, wrong document ID, unknown/missing top-level key, wrong top-level type, unsupported schema, simple scalar/list over-bound, evaluation-contract, audit, and authoring-namespace reads fail.
- [ ] Prove every authenticated create/update/delete fails for configuration, pointers, versions, assets, rubrics, private version heads/evaluation contracts, and audit.
- [ ] Keep the final catch-all deny and all existing profile protections.
- [ ] Do not add a broad curriculum list query. Implement exactly Section 4.9: Rules establish auth, the allowlisted top-level shape/types/simple bounds, publication marker, and denial; Node/Swift—not Rules—establish nested unions, uniqueness/order, cross-document graph, canonicalization, and SHA-256 integrity.
- [ ] Add no index unless a later test-backed query contract requires it.
- [ ] Update the exact Rules count to the observed complete total.

Run:

```bash
./scripts/test_firebase_rules.sh
```

Expected: all profile and exact-get curriculum Rules tests pass with zero failure, skip, cancel, or count drift.

### Task 5 — Define the Swift curriculum domain test-first

**Files**

- Create: `Syntholo/Services/Curriculum/CurriculumIdentifiers.swift`
- Create: `Syntholo/Services/Curriculum/CurriculumModels.swift`
- Create: `Syntholo/Services/Curriculum/CurriculumCanonicalJSON.swift`
- Create: `Syntholo/Services/Curriculum/CurriculumValidation.swift`
- Create: `Syntholo/Services/Curriculum/CurriculumRepository.swift`
- Create: `SyntholoTests/CurriculumModelsTests.swift`
- Create: `SyntholoTests/CurriculumValidationTests.swift`
- Modify: `project.yml` to add only `tests/fixtures/content/` and digest vectors as test-bundle resources, never app resources

- [ ] Write failing tests for stable/locale/version IDs, exact schema parity, synthetic fixture decoding, shared digest vectors, duplicate identities, catalog order, prerequisite DAG, asset/rubric references, public scoring contract, malformed blocks, digest mismatch, and compatibility rejection.
- [ ] Confirm RED before Swift implementation.
- [ ] Implement small `Codable`, `Equatable`, `Hashable`, `Sendable` values and the closed block/completion unions.
- [ ] Implement the exact `AsyncStream<CurriculumLoadEvent>` boundary from Section 6.1.
- [ ] Model only learner-readable rubric/client scoring data; no protected evaluation-contract payload enters the app domain.
- [ ] Keep Firebase, file-system, SwiftUI, and authoring-only rights workflow types out of the core domain where not needed.

Run focused tests:

```bash
./scripts/bootstrap.sh
destination="${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination "$destination" -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoTests/CurriculumModelsTests \
  -only-testing:SyntholoTests/CurriculumValidationTests
```

Expected: Node and Swift consume the same fixtures/vectors and produce identical validation/digests under strict concurrency.

### Task 6 — Build the app-owned cache test-first

**Files**

- Create: `Syntholo/Services/Curriculum/CurriculumCache.swift`
- Create: `Syntholo/Infrastructure/Persistence/FileCurriculumCache.swift`
- Create: `SyntholoTests/CurriculumCacheTests.swift`

- [ ] Write failing tests for round trip, atomic replacement, environment/project/locale separation, corrupt/wrong envelope, malformed graph, digest mismatch, incompatible snapshot, failed write preserving the prior valid cache, and deterministic quarantine naming.
- [ ] Confirm RED before implementation.
- [ ] Implement the cache as an actor and inject root URL/clock in tests.
- [ ] Revalidate the complete locale catalog snapshot before returning it.
- [ ] Ensure quarantine failure never turns invalid data into valid data or deletes a separately valid snapshot.

Run the focused `CurriculumCacheTests` with the same Xcode settings as Task 5.

Expected: the last valid graph survives every expected local failure and cache namespaces never cross.

### Task 7 — Implement the exact-get Firestore adapter test-first

**Files**

- Create: `Syntholo/Infrastructure/Firebase/FirestoreCurriculumRepository.swift`
- Create: `SyntholoTests/CurriculumRepositoryContractTests.swift`
- Review: `Syntholo/Infrastructure/Firebase/FirebaseBootstrap.swift`
- Review: `Syntholo/Infrastructure/Firebase/FirebaseRuntimeConfiguration.swift`

- [ ] Write failing recording-store tests for the exact Section 6 event order and exact configuration/catalog/pinned-program-version/module/lesson/rubric/asset paths; assert that no mutable program-pointer path is read while resolving a snapshot.
- [ ] Cover saved→fresh, saved→unavailable (including remote publication disappearance), saved→update-required from the compatibility header, no-cache empty for missing header/unsupported locale, advertised-but-missing pointer/target as unavailable, compatible-header unsupported content as unavailable, offline, cancellation, duplicate suppression, order preservation, broken references, malformed values, and digest rejection.
- [ ] Encapsulate non-`Sendable` Firebase SDK types through the established isolated-store pattern.
- [ ] Force server-source refresh and never issue a curriculum collection list query.
- [ ] Never request `evaluationContractVersions` or audit documents from the client.
- [ ] Validate the complete snapshot before cache replacement and keep profile behavior unchanged.
- [ ] Make UI tests inject a memory repository; no emulator port dependency during XCUITest.

Run focused `CurriculumRepositoryContractTests`.

Expected: the adapter yields only complete compatible exact-version catalog snapshots and preserves a valid fallback.

### Task 8 — Build Learn state and read-only screens test-first

**Files**

- Create: `Syntholo/Features/Learn/CurriculumStore.swift`
- Create: `Syntholo/Features/Learn/LearnRoute.swift`
- Create: `Syntholo/Features/Learn/ProgramDetailView.swift`
- Create: `Syntholo/Features/Learn/ModuleDetailView.swift`
- Create: `Syntholo/Features/Learn/LessonPreviewView.swift`
- Create: `Syntholo/Features/Learn/CurriculumStatusView.swift`
- Create: `SyntholoTests/CurriculumStoreTests.swift`
- Modify: `Syntholo/Features/Learn/LearnHomeView.swift`
- Modify: `Syntholo/Resources/Localizable.xcstrings`

- [ ] Write failing store tests for every stream transition, retry, cancellation, duplicate-load suppression, and place preservation.
- [ ] Implement `@MainActor @Observable CurriculumStore` with an `Equatable` state and `@ObservationIgnored` dependencies/task.
- [ ] Replace Learn placeholder content with the ordered locale catalog and honest `comingSoon` state.
- [ ] Render stable-ID program/module/lesson rows and the read-only objective, duration, concept, diagram, question, and non-sensitive rubric/version metadata.
- [ ] Keep all fixed copy in `Localizable.xcstrings`; do not use runtime casing.
- [ ] Do not render the correct answer or implement response controls, scoring, completion, or progress.

Run focused `CurriculumStoreTests` and an app build on iOS 17.

Expected: every Section 6 state renders from the exact event contract without newer-only APIs.

### Task 9 — Connect typed preview navigation and same-session handoff

**Files**

- Create: `Syntholo/App/AppDependencies.swift`
- Modify: `Syntholo/App/AppRouter.swift`
- Modify: `Syntholo/App/AppRoute.swift`
- Modify: `Syntholo/App/RootView.swift`
- Modify: `Syntholo/Features/Onboarding/OnboardingRootView.swift`
- Modify: `Syntholo/Features/Onboarding/FirstLessonHandoffView.swift`
- Modify: `SyntholoTests/AppRouterTests.swift`
- Create or modify: a focused root-flow test file

- [ ] Write failing tests proving the route retains locale/catalog/program/module/lesson/rubric versions, failure leaves `.firstLessonHandoff`, duplicate taps start one stream, and success installs the route before `.signedIn`.
- [ ] Construct coordinator, repository/cache/store, analytics, and test fixtures once in root composition.
- [ ] Use typed Learn navigation without changing the four-tab contract or injecting Firestore into onboarding.
- [ ] Present loading/disabled/retry and label the Phase 2 action **Preview the first lesson**.
- [ ] Transition only after the exact preview route is ready; returning learners land on Learn home.

Expected: the preview opens directly without catalog/paywall/notification/social interruption, while evidence explicitly leaves `SHIP-FIRST-LESSON` incomplete until Phase 3.

### Task 10 — Add deterministic UI fixtures and end-to-end UI coverage

**Files**

- Create: Debug-only `Syntholo/Features/Learn/CurriculumFixtures.swift`
- Create: `SyntholoUITests/CurriculumUITests.swift`
- Modify: `Syntholo/App/RootView.swift`
- Modify: onboarding/shell UI test files
- Modify: `scripts/test.sh`

- [ ] Add memory fixtures for fresh, saved, saved→fresh, offline/no cache, incompatible with/without fallback, empty, malformed, and fail-once/retry.
- [ ] Ensure `--ui-testing` never contacts live Firestore.
- [ ] Require the exact preview title/objective after onboarding and test catalog → program → module → preview.
- [ ] Prove the absence of catalog/paywall/notification/social interruption before preview.
- [ ] Add accessibility audits for catalog and preview states.
- [ ] Update exact unit/functional/accessibility totals only after discovery and GREEN results.

Run focused UI tests, then `./scripts/test.sh`.

Expected: zero failed/skipped/canceled tests and exact totals.

### Task 11 — Add privacy-safe analytics

**Files**

- Modify: `Syntholo/Services/Analytics/AnalyticsClient.swift`
- Modify: `Syntholo/Infrastructure/Firebase/FirebaseAnalyticsClient.swift`
- Modify: `SyntholoTests/AnalyticsEventTests.swift`
- Modify: `Syntholo/Features/Learn/CurriculumStore.swift`

- [ ] Write failing typed-payload tests first.
- [ ] Add `program_viewed`, `module_viewed`, and `lesson_viewed`; optional sync events use stable IDs, locale, freshness/source, duration bucket, and safe error code only.
- [ ] Make title/body/question/options/correct answer/feedback/prompt/submission/email/profile/operator fields unrepresentable in the typed API.
- [ ] Emit one view event per route presentation; body reevaluation emits none, while a later distinct presentation may emit another.

Run focused `AnalyticsEventTests`.

Expected: no curriculum or learner text can enter analytics.

### Content-load gate — mandatory stop

Tasks 1–11 may finish with synthetic fixtures while the specialization is unresolved. Before Task 12:

- [ ] The Product Bible contains a dated accepted choice of School, Work, Creation, or Build.
- [ ] `content/config/launch-content-decision.json` is tracked, validates, cites that Bible decision, and matches it exactly.
- [ ] The staging Firebase project ID/number and approved keyless impersonated publisher principals are supplied by the environment owner and added to `content/config/environments.json`.
- [ ] Product and curriculum owners authorize original Foundations fixture authoring and staging load.

If any item is missing, stop. Phase 2 remains in progress; do not author learner-facing content, write staging, or claim the gate waived.

### Task 12 — Author and validate the original Foundations fixture

**Files**

- Create only after the gate: `content/drafts/ai-foundations-v1.json`
- Create: `tests/content/ai-foundations-fixture.test.mjs`

- [ ] Write failing fixture-specific tests before the original draft.
- [ ] Author one original `ai-foundations` program, one module, and one structurally valid read-only lesson preview fixture about forming a clear request. Do not call it a Product Bible “complete lesson”: Phase 3 must add response capture, feedback/revision flow, and recorded outcomes.
- [ ] Include an objective, duration, exact completion rule, stable prerequisites, concept, original diagram asset and text alternative, rights metadata, realistic applied single-answer check, deterministic feedback, public rubric/client scoring contract, and matching protected evaluation contract.
- [ ] Include the locale catalog membership and exact first-lesson pointer; do not create specialization lessons or pretend the Phase 2 sample satisfies the full 3-module/12-lesson/capstone requirement.
- [ ] Complete curriculum, copyright/rights, safety, and accessibility review.
- [ ] Confirm the draft stays outside `Syntholo/` and the app target resources.

Run:

```bash
npm run content:validate -- content/drafts/ai-foundations-v1.json
node --test tests/content/ai-foundations-fixture.test.mjs
npm run content:publish -- --dry-run --operation-id <uuid> \
  --environment staging --project <approved-staging-project-id> \
  --confirm-project <approved-staging-project-id> \
  --source content/drafts/ai-foundations-v1.json
```

Expected: the reviewed original fixture is GREEN and the staging dry-run shows only safe metadata with no write.

### Task 13 — Certify accessibility, localization, staging, rollback, and secrets

**Files**

- Create: `docs/quality/2026-08-30-phase-2-curriculum-platform-verification.md`
- Modify implementation only for verified defects

- [ ] Complete VoiceOver order/labels, diagram text alternative, Dynamic Type, 44×44/48-point targets, non-color status, Reduce Motion, and Switch Control checks.
- [ ] Audit String Catalog coverage and runtime casing.
- [ ] Run the full gate on current iOS and the iOS 17.5 CI destination.
- [ ] Review the staging `--dry-run`, then publish with `--apply`, an approved keyless impersonated publisher principal, and a unique operation ID.
- [ ] Verify exact staging-device load/cache/relaunch/refresh.
- [ ] Publish a safe v2 staging revision, prove v1 immutability, reject publishing v1 over v2, then use rollback to select v1 and prove the app resolves it.
- [ ] Verify authenticated client exact reads and all content/private writes denied under production-shaped staging Rules.
- [ ] Run the approved scanner over full Git history, worktree, logs/reports, and the built `.app`; inspect the bundle for credentials/tokens. Record explicit allowlisted public Firebase client configuration separately.
- [ ] Capture versions, commands, exact test totals, screenshots/recordings, IDs/digests, derived principal, operation/audit IDs, Rules denial, rollout, rollback, scanner version/result, and approvals.

Final commands:

```bash
./scripts/test.sh
./scripts/scan_secrets.sh --history --worktree --generated DerivedData --bundle <absolute-path-to-Syntholo.app>
git ls-files '*service-account*.json' '*GoogleService-Info.plist' '*.firebase.plist'
git status --short
```

Expected: gates are GREEN, the full secret/bundle scan finds no credential, the supplemental filename search is empty, and only intended source/evidence changes remain.

## 9. Acceptance matrix

| Scenario | Required proof |
| --- | --- |
| Specialization unresolved | Only synthetic schema/tool/emulator work proceeds; original draft/staging/exit are blocked |
| Valid draft | Pure validator produces stable shapes and digests |
| Invalid draft | Nonzero exit; no Firestore writes |
| Canonicalization | Node and Swift pass the same RFC 8785 golden vectors and document digests |
| First publish | Immutable catalog pins exact program versions; graph, pointers, configuration, and derived-principal audit appear atomically |
| Same live version/same digest | Only when every immutable/head/pointer/config value already matches: new operation writes exactly one `noOp` audit; exact replay writes nothing |
| Same version/different digest | Hard failure; pointer unchanged |
| Existing non-live catalog/program selection via publish | Rejected with “use rollback”; audit/pointer unchanged |
| Historical version monotonicity | Atomic private version heads prove every newly created immutable version exceeds the maximum ever published for its stable identity/locale, including after rollback |
| Operation replay/collision | Exact replay returns its recorded applied/no-op result even after live state changes; reused ID with changed request fails |
| Environment/principal mismatch | Disguised project or unapproved ADC principal fails before writes |
| Roll forward | Pointer changes to v2; v1 remains byte-for-byte/digest stable |
| Catalog rollback | Locale catalog pointer and its program selections return atomically to a prior validated manifest; later versions remain immutable; audit records the full transition |
| Repeated rollback to live target | New operation writes one `noOp` audit and no pointer; replay of that operation writes nothing |
| Unauthorized learner | Exact reads require auth; all curriculum/private/audit writes fail; Rules prove only the Section 4.9 shallow boundary |
| Protected evaluation contract | Publisher validates it; learner read is denied; client uses only explicitly non-secret scoring data |
| Fresh online app | Exact locale catalog graph validates, renders in manifest order, and replaces cache |
| Valid cache + offline | Saved graph renders with non-color saved status and retry |
| No cache + offline | Place is preserved; recoverable unavailable state appears |
| Missing header/unsupported locale + no cache | Empty state appears; an advertised missing pointer/version is unavailable instead |
| Remote compatibility header requires newer client + compatible cache | Update-required is explicit before new content fetch; saved graph remains usable |
| Remote compatibility header requires newer client + no cache | Update-required blocks unsafe rendering and offers App Store/update guidance later without crashing |
| Unsupported document behind compatible header | Backend-contract failure is unavailable, not a misleading update-required or empty state |
| Corrupt cache | Cache is ignored/quarantined; remote can recover it |
| Broken reference/digest | Remote graph is rejected; last valid cache remains |
| New onboarding | Phase 2 Preview CTA resolves the exact lesson preview before catalog/shell; no lesson-start claim is made |
| Returning learner | Signed-in restore reaches Learn home and can browse valid content |
| Accessibility | Automated audits plus physical VoiceOver/Dynamic Type/Control verification pass |
| Privacy | Typed analytics contain IDs/versions only; history/worktree/log/bundle scanner is clean |

## 10. Phase 2 exit evidence

Phase 2 may be marked complete only when `docs/quality/2026-08-30-phase-2-curriculum-platform-verification.md` proves all of the following:

- [ ] The binding requirements above map to implementation files and passing tests.
- [ ] The Product Bible contains the dated approved launch specialization, the derivative decision gate matches it, and no plan invented or inferred the choice.
- [ ] One original AI Foundations fixture validates and publishes through the constrained operator path.
- [ ] Publication creates an immutable catalog that pins exact program versions plus exact content/asset/public-rubric/private-evaluation documents, advances required locale/program pointers atomically, and writes a derived-principal audit event.
- [ ] A tested catalog rollback selects a previously valid immutable snapshot and restores its program selections without rewriting, creating, or deleting history.
- [ ] Atomic private version heads prove every new immutable version exceeds its identity's historical maximum; rollback never lowers them; publish cannot select an existing non-live catalog/program version; audited no-op, operation replay/collision, and repeated-rollback behavior match Section 5 exactly.
- [ ] Firestore Rules allow only the authenticated shallow exact-get contract in Section 4.9 and deny all learner writes/private reads; Node/Swift tests separately prove nested shape/graph/digest validity.
- [ ] The iOS repository validates exact locale catalog order, references, compatibility, prerequisites, assets, public scoring references, and digests before cache replacement.
- [ ] Fresh, cached, stale, empty, offline, malformed, incompatible, and retry behavior are automated.
- [ ] The clearly labeled Phase 2 preview CTA opens the exact first lesson preview in the same session without catalog, paywall, notification, or social interruption; evidence states `SHIP-FIRST-LESSON` remains incomplete until Phase 3.
- [ ] Learn catalog, program detail, module detail, and read-only lesson preview render from real versioned records.
- [ ] Static interface copy is in `Localizable.xcstrings`; dynamic curriculum carries locale/version metadata.
- [ ] Analytics tests enforce `LAW-19` and learner/content text is absent from payloads.
- [ ] Accessibility audits and named physical checks cover every Phase 2 screen/state.
- [ ] `./scripts/test.sh` passes with exact updated totals and zero failure, skip, or cancellation on both supported CI destinations.
- [ ] Staging publication/read/cache/roll-forward/existing-non-live-publish rejection/catalog rollback evidence exists with approved project, derived credential principal, applied/no-op operation IDs, IDs, digests, and timestamps but no sensitive content.
- [ ] Full-history, worktree, generated-log/report, and built-app secret scans pass; the filename search is supplemental only.
- [ ] There is no open Phase 2 P0/P1 data-integrity, content-exposure, credential, crash, or critical accessibility defect.

**Exit statement:** With the Product Bible's specialization decision recorded, an allowlisted authenticated operator can publish and roll back a validated immutable Foundations fixture; unauthorized writes/private reads fail; and a signed-in learner opens and renders the exact compatible locale catalog/version online or from the last valid cache. Phase 2 proves a preview seam only. After this evidence is approved, Phase 3 may define attempts, starts, scoring, allowance, progress, and durable learner-work queues and complete `SHIP-FIRST-LESSON`.

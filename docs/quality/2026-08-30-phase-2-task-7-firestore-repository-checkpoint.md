# Syntholo Phase 2 Task 7 exact-get Firestore repository checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 6.1–6.3 and Task 7

**Implementation commit:** `83f6e1a` (`feat(curriculum): add exact firestore repository`)

**Documentation provenance:** introduced in `7a86530` (`docs(curriculum): record Task 7 checkpoint`); this field is finalized by the immediately following provenance commit

## Result

The Phase 2 Task 7 exact-get repository engineering checkpoint is complete. Syntholo now has a concrete authenticated Firestore adapter that emits the frozen `AsyncStream<CurriculumLoadEvent>` sequence, restores a compatible app-owned snapshot before refreshing, forces server-source exact document reads, assembles only the catalog-pinned immutable learner graph, validates the complete graph and every digest, and replaces the cache only after complete success.

This is not Phase 2 completion, launch approval, or a learner-visible curriculum release. The observable store and read-only Learn screens are Task 8. Root dependency composition and the onboarding preview handoff are Task 9. The debug memory repository and the proof that `--ui-testing` never contacts Firestore remain explicitly assigned to Task 10, because no curriculum UI/root composition seam exists yet.

## Test-first evidence

The valid RED sequence was observed after regenerating the Xcode project:

1. The expanded runtime-identity tests failed because Firebase project-number provenance did not exist.
2. The repository contract tests then failed because the Task 7 document-store seam and concrete repository symbols did not exist.

The settled focused command was:

```bash
./scripts/bootstrap.sh
xcodebuild test -quiet \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  -parallel-testing-enabled NO \
  -only-testing:SyntholoTests/CurriculumRepositoryContractTests \
  -only-testing:SyntholoTests/CurriculumCacheTests \
  -only-testing:SyntholoTests/FirebaseRuntimeConfigurationTests
```

Result: 69 passed, 0 failed, and 0 skipped. The repository contract contributes 30 tests. The complete Swift unit target passed 176/176, and the canonical exact-count harness is pinned to 176.

## Repository boundary delivered

- `CurriculumDocumentStore` is a finite async exact-get seam with no query, list, listener, or write capability.
- The production store always calls Firestore with `.server` and converts SDK values into `Sendable` curriculum values before they cross the adapter boundary.
- Timestamp seconds and nanoseconds are preserved. Booleans remain distinct from integers. Floating-point numbers, including integral-looking doubles, unsupported Firebase values, and timestamp-shaped maps fail closed with the exact document path.
- The production initializer derives the cache source from validated `FirebaseRuntimeConfiguration` plus the actual Firestore app options. Cloud project ID and project number must match; the emulator uses its explicit development-only identity.
- Firestore `unauthenticated`, network/deadline, cancellation, permission, malformed-value, and backend failures map to stable repository errors. Permission denial is not misreported as an authentication challenge.

## Exact resolution and event contract

One load performs this bounded sequence:

1. Construct the environment/project/locale cache scope and fully revalidate its saved graph.
2. Yield at most one `.saved` snapshot.
3. Exact-get `featureConfiguration/curriculum` from the server and check the backward-readable minimum-client field before strict schema-v1 decoding.
4. Exact-get `catalogs/en-us`, repeat the minimum-client check, and capture its immutable catalog version.
5. In first-encounter reference order, exact-get the pinned catalog version, program versions, modules, lessons, learner-readable rubrics, and assets.
6. Strictly decode identities, locale, timestamps, schema fields, graph ownership/order/prerequisites, public scoring references, canonical bytes, and document/payload digests.
7. Atomically replace the app cache only after complete validation, then yield `.fresh`.

The adapter never reads mutable `programs/` pointers while resolving a snapshot and never requests private evaluation contracts, version heads, publication audit records, authoring records, or a collection list/query. Shared rubric and asset targets are fetched once while preserving first-encounter order.

Missing configuration or an unsupported locale yields `.empty` only when no saved graph exists. Withdrawal after a saved result yields `.unavailable(.notPublished, saved:)`. An advertised missing pointer, immutable target, or descendant is a broken publication and never becomes `.empty`. Compatible headers followed by unsupported immutable content fail closed as unavailable. Cache replacement failure never claims freshness or erases the saved fallback.

## Cancellation and cache commit semantics

Dropping iteration cancels the repository worker and pending document read. A lock-protected one-shot continuation gate ignores late Firestore callbacks. Cancellation before cache commit prevents directory creation and write mutation.

The cache uses a short commit-state gate: `ready → cancelled` and `ready → committing` are mutually exclusive. The lock is released before filesystem I/O, so cancelling code never blocks behind a slow atomic write. If cancellation wins, no write starts. If commit wins, the synchronous atomic replacement completes and cancellation returns promptly without corrupting the file. Deterministic tests prove both sides of this linearization boundary.

## Focused contract coverage

The 30 repository tests cover:

- exact happy-path events and the complete allowed path sequence;
- saved → fresh, saved → unavailable, saved → update-required, and the two no-cache empty cases;
- configuration and pointer compatibility preflights, strict launch-locale configuration, exact keys, real timestamps, malformed values, and future fields;
- missing pointer/catalog/program/module/lesson/rubric/asset targets;
- mismatched returned catalog/program/module/lesson/rubric/asset identities;
- unsupported immutable schema/minimum-client values;
- malformed Firestore normalization with exact path retention and direct SDK-error classification;
- digest, ownership, accessibility/asset-semantic, and cache-replacement failure taxonomy;
- invalid-cache recovery, shared-target deduplication, and mutation-resistant non-lexical program/module/lesson/rubric/asset ordering;
- cancellation during remote resolution and before cache mutation.

The adjacent cache/runtime tests additionally prove non-blocking commit linearization and cloud/emulator Firestore-source identity matching.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Task 7 result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 176 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **407 passed** |

The run used iPhone 17 Pro / iOS 26.5. The recurring Xcode `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version` messages remained non-failing tooling warnings; no test was retried, skipped, or masked.

## Toolchain and security evidence

- macOS 26.6.2 (25G83)
- Xcode 26.6 (17F113), Apple Swift 6.3.3, project language mode Swift 6
- XcodeGen 2.46.0
- Node 22.23.2 and npm 10.9.8
- OpenJDK 21.0.12.1
- Project-local Firebase CLI 15.28.1
- Gitleaks 8.30.1

The canonical history and first-party worktree scans were clean. A separate standalone Release simulator build succeeded. Its direct app-bundle scan examined approximately 150.10 KB and its extracted strings/normalized-plist scan examined approximately 4.11 MB; both were clean under the pinned Gitleaks policy. The bundle contained and embedded none of `minimal-curriculum-v1.published-client.json`, `minimal-coming-soon-program-v1.published-client.json`, or `curriculum-v1.digest-vectors.json`.

This is strong source/resource-separation evidence, not signed App Store archive certification. The Firebase SDK remains in the production app as expected; synthetic curriculum fixtures remain test-only.

## Independent review

Three independent architecture, contract, and risk/test reviews found and drove repairs for:

- caller-forgeable cache provenance;
- malformed Firebase values losing their document path;
- overly permissive launch-locale configuration;
- permission-denied misclassification;
- asset semantic defects being mislabeled as missing references;
- weak immutable identity and nested-order regression coverage;
- fixed-sleep cancellation checks and a cache write/cancellation race;
- a commit gate that initially held its lock across filesystem I/O.

The final source identity is derived from validated runtime and actual Firestore app metadata. Error taxonomy is directly tested. All immutable identity guards and every nested order are mutation-resistant. Cancellation uses deterministic latches, and the final commit gate does not hold a lock across I/O. The final independent verdict reports no remaining P0, P1, or P2 Task 7 issue.

## Deliberate non-claims and open work

- No SwiftUI view, curriculum store, root composition, onboarding route, or learner-visible behavior changed in Task 7. The SwiftUI Expert guidance kept Firebase and cache concerns outside view state.
- UI-test memory repository injection is not claimed; it remains Task 10 after Tasks 8–9 create the store and composition seams.
- No original learner-facing content was authored, no specialization was selected or inferred, and no staging or production Firebase write occurred.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent; `content/config/environments.json` remains emulator-only.
- No live Firebase/staging read was used as evidence. Production adapter behavior is covered through the isolated document-store boundary and SDK error/value classifiers.
- Only iOS 26.5 ran locally; minimum-iOS 17 CI runtime evidence remains absent.
- The Release artifact was an unsigned simulator app, not a signed physical-device archive.
- Live providers, physical accessibility, production-shaped Rules/device proof, Git remote/branch protection, and named owner approvals remain open.
- Task 8 is next: the observable curriculum store plus honest loading/saved/fresh/empty/update-required/unavailable states and read-only catalog/program/module/lesson preview UI.

Phase 2 remains in progress, and all Product Bible release gates remain unsatisfied.

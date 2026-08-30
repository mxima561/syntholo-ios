# Syntholo Phase 2 Task 6 app-owned curriculum-cache checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 6.1, 6.2, and Task 6

**Implementation commit:** `ba54963` (`feat(curriculum): add validated app cache`)

**Documentation provenance:** introduced in `fd05c5d` (`docs: record Task 6 cache checkpoint`); this field is finalized by the immediately following provenance commit

## Result

Phase 2 Task 6 is complete. Syntholo now has an app-owned actor-isolated cache that can persist and restore a complete learner-readable curriculum snapshot without crossing environment, Firebase-project, or locale boundaries. Every replacement is fully validated before filesystem mutation, and every returned snapshot is revalidated from its exact cache envelope.

This is not Phase 2 completion or launch approval. It does not implement the concrete Firestore exact-get repository, saved/fresh event orchestration, curriculum store or UI, first-preview handoff, original curriculum, staging publication/load, or any Product Bible release gate.

## Test-first evidence

After the generated Xcode project included the new cache test source, the focused command failed for the intended reason: `CurriculumCacheScope`, `CurriculumCacheError`, the cache filesystem boundary, and the concrete cache did not exist. That was the valid RED state.

The settled focused command was:

```bash
./scripts/bootstrap.sh
destination="${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination "$destination" -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -only-testing:SyntholoTests/CurriculumCacheTests
```

Result: 25 passed, 0 failed, and 0 skipped. The complete Swift unit target passed 143/143, and the canonical exact-count harness is pinned to 143.

## Cache boundary delivered

- `CurriculumCacheEnvironment` explicitly distinguishes development, staging, and production.
- `CurriculumCacheScope` validates safe project IDs, project numbers, and locales before any path is constructed.
- `CurriculumCache` exposes only asynchronous load and validated replacement operations with typed errors.
- `FileCurriculumCache` is an actor with injected root URL, clock, and filesystem seam.
- The exact location is `Curriculum/<environment>/<projectID>/<locale>/catalog-snapshot-v1.json`.
- Firebase SDK values, SwiftUI state, remote refresh behavior, and protected evaluation data do not enter the cache boundary.

## Exact versioned envelope and validation

The V1 envelope records:

- envelope version and bounded UTC save timestamp;
- environment, project ID, and project number;
- locale and exact catalog pointer/version;
- ordered catalog program entries and pinned versions;
- an ordered digest manifest covering every learner-readable catalog, program, module, lesson, rubric, and asset document;
- the complete bounded learner-readable snapshot.

The cache rejects files larger than 10 MiB, runs the existing strict JSON preflight, rejects duplicate keys including escaped-equivalent names, requires integer number syntax, and decodes exact closed envelope/source/manifest keys. It then verifies envelope version, timestamp bounds, requested source identity, header/snapshot parity, exact manifest order/multiplicity/completeness, every document digest, compatibility, and the complete curriculum graph through `CurriculumValidator`.

Replacement performs the same complete graph/source validation before creating a directory or writing bytes. Production replacement uses `Data.write(..., .atomic)`.

## Failure containment and quarantine

Invalid primary data is moved beside the cache as:

`catalog-snapshot-v1.invalid-<UTC-milliseconds>.json`

Corrupt/truncated JSON, oversized input, unknown or missing envelope fields, unsupported envelope versions, wrong source, header parity failures, malformed graphs, digest mismatches, incompatible snapshots, and invalid saved timestamps fail closed.

A transient filesystem read failure returns `.readFailed` without quarantining the valid primary. Failed writes and invalid injected clocks return `.writeFailed` without touching the prior valid snapshot. Quarantine failure or a pre-existing quarantine-name collision never promotes invalid bytes, overwrites the prior quarantine, or deletes a separately valid scope.

## Focused coverage

The 25 focused tests cover:

- complete round trip and exact envelope metadata;
- atomic replacement;
- environment/project/locale isolation;
- missing-cache behavior;
- corrupt/truncated and oversized data;
- exact unknown/missing keys and escaped-equivalent duplicate keys;
- unsupported envelope version and the wrong-source matrix;
- header/snapshot parity;
- malformed graph and real document-digest failure;
- digest-manifest mismatch, ordering, duplication, and omission;
- incompatible snapshot and timestamp bounds;
- failed write, transient read, invalid clock, and invalid replacement preserving prior valid data;
- exact quarantine naming, quarantine failure, and collision behavior;
- unsafe path-component rejection.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 143 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **374 passed** |

The run used iPhone 17 Pro / iOS 26.5. The recurring Xcode `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version` messages remained non-failing tooling warnings; no test was retried, skipped, or masked.

## Toolchain and security evidence

- macOS 26.6.2 (25G83)
- Xcode 26.6 (17F113), Apple Swift 6.3.3, project language mode Swift 6
- XcodeGen 2.46.0
- Node 22.23.2 and npm 10.9.8
- OpenJDK 21.0.12.1
- Firebase CLI 15.28.1
- Gitleaks 8.30.1

The canonical full-history and first-party worktree scans were clean. A separate standalone Release simulator build succeeded. Its direct app-bundle scan examined approximately 150.10 KB and its extracted strings/normalized-plist scan examined approximately 4.11 MB; both were clean under the pinned Gitleaks policy. The bundle contained none of `minimal-curriculum-v1.published-client.json`, `minimal-coming-soon-program-v1.published-client.json`, or `curriculum-v1.digest-vectors.json`.

A separate diagnostic scan of the complete 1.37 GB `DerivedData` tree reported 102 redacted matches: 94 generic-key and 8 GCP-key signatures. Path/rule triage placed all of them in downloaded Firebase/GoogleSignIn source and test fixtures, the Firebase repository pack, gRPC/OpenSSL artifacts and code signatures, or copied third-party private headers. None was in first-party source or the scanned Release app bundle. This is strong resource-separation evidence, but it is not signed App Store archive certification.

## Independent review

Independent implementation and failure-mode reviews identified one material issue during development: generic/transient read I/O failures initially followed the invalid-data quarantine path. The cache now distinguishes unreadable storage from invalid bytes, returns `.readFailed`, and preserves the valid primary for retry.

After that fix, the final independent verdict found no remaining P0, P1, or P2 Task 6 issue. Path construction rejects traversal-capable project identifiers. Swift 6 normal builds report no new first-party warning. A repository-wide warnings-as-errors probe is not claimed because third-party Firebase/GTM packages combine their own suppression and warnings-as-errors flags.

Production atomicity relies on Foundation `Data.write(..., .atomic)`; the injected test seam proves that a failed replacement does not mutate the prior cache, but minimum-iOS runtime and physical-device crash/power-loss evidence remain release work.

## Deliberate non-claims and open work

- No original learner-facing content was authored.
- No staging or production Firebase write occurred.
- No specialization was selected or inferred.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent.
- `content/config/environments.json` remains emulator-only.
- Task 7 is next: the concrete authenticated exact-get Firestore repository and deterministic saved/fresh/terminal event sequence.
- Tasks 8–13 remain open: store/UI, preview handoff, UI/accessibility fixtures, analytics, approved content/staging enablement, and certification.
- Only iOS 26.5 ran locally; minimum-iOS 17 CI runtime evidence remains absent.
- Live providers, physical accessibility, production-shaped Rules, signed-release scanning, Git remote/branch protection, and named owner approvals remain open.

Phase 2 remains in progress, and all Product Bible release gates remain unsatisfied.

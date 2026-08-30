# Syntholo Phase 2 Task 5 Swift curriculum-domain checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Sections 4, 6.1, and Task 5

**Implementation commit:** `f3a07ec` (`feat(curriculum): add validated Swift domain`)

**Documentation provenance:** introduced by the documentation commit immediately after the implementation commit; finalized by the following provenance commit

## Result

Phase 2 Task 5 is complete. Syntholo now has a pure Swift 6 curriculum domain that can decode, identify, canonicalize, hash, and validate a complete learner-readable locale snapshot before later cache or UI code may accept it. Node and Swift share the same synthetic public projection and digest evidence. The exact `AsyncStream<CurriculumLoadEvent>` boundary from Section 6.1 is present, while its concrete cache and Firestore implementations remain correctly assigned to Tasks 6 and 7.

This is not Phase 2 completion or launch approval. It does not implement the app-owned cache, the Firebase exact-get adapter, curriculum UI, the first-preview handoff, original curriculum, a staging publication/load, or any Product Bible release gate.

## Test-first evidence

After the test-only fixture and digest-vector resources were added to the generated Xcode project, the focused Task 5 command failed for the intended reason: the new tests referenced curriculum identifiers, models, validation, canonicalization, and repository-boundary symbols that did not exist. That was the valid RED state. An earlier invocation made before regenerating the Xcode project discovered zero Task 5 tests and was rejected as invalid evidence; it is not used for this checkpoint.

The settled focused command was:

```bash
./scripts/bootstrap.sh
destination="${SYNTHOLO_DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo \
  -destination "$destination" -derivedDataPath DerivedData \
  CODE_SIGNING_ALLOWED=NO -parallel-testing-enabled NO \
  -only-testing:SyntholoTests/CurriculumModelsTests \
  -only-testing:SyntholoTests/CurriculumValidationTests
```

Result: 12 passed, 0 failed, and 0 skipped. The complete Swift unit target passed 118/118, and the exact-count assertion harness rejects 117 as drift.

## Domain boundary delivered

- Typed stable IDs, locale values/tokens, positive bounded versions, pointer/version/catalog IDs, and lowercase SHA-256 digests.
- Exact, closed, manually decoded learner-readable catalog, program, module, lesson, rubric, scoring, asset, rights, diagram, block, completion-rule, and timestamp values.
- Required nullable fields remain distinguishable from omitted optional fields; unknown keys, unknown discriminators, and wrong primitive types fail decoding.
- All domain values required by the boundary are `Codable`, `Equatable`, `Hashable`, and `Sendable`.
- `CurriculumLoadEvent` has exactly `saved`, `fresh`, `empty`, `updateRequired`, and `unavailable`; `CurriculumRepository` returns `AsyncStream<CurriculumLoadEvent>`.
- Firebase SDK values, file-system/cache concerns, SwiftUI, authoring envelopes, and protected evaluation-contract payloads do not enter the core domain.
- The public rubric retains only learner-readable scoring metadata and the opaque protected evaluation-contract version reference required by the published schema.

The SwiftUI Expert skill informed the implementation boundary: stable value identity, immutable/sendable models, iOS 17-compatible APIs, and no view, navigation, Firebase, or persistence coupling inside the Task 5 core.

## Strict ingress and bounded failure behavior

Before `JSONDecoder` allocates the complete object graph, the curriculum codec performs a strict byte-level preflight:

- maximum snapshot input: 9 MiB;
- maximum nesting depth: 128;
- maximum members in one object: 32;
- maximum items in one array: 180;
- duplicate keys are rejected after escape decoding, including escaped-equivalent names;
- only JSON integer syntax is accepted; decimal and exponent lexemes such as `1.0` and `1e0` fail in both Node and Swift;
- malformed syntax and non-integer numbers produce typed, payload-redacted errors.

The complete decoded graph is then hard-gated to the frozen document and nested collection bounds before recursive graph or digest work. Validation issues are deduplicated with a set. An independent probe that previously raised peak memory to roughly 161 MiB with 500,000 unique keys now rejects in under one millisecond with bounded key storage.

## Learner-graph validation delivered

Swift independently rejects every learner-visible invariant derivable from the public snapshot:

- launch locale, publication state, schema compatibility, minimum-client compatibility, and exact Firestore timestamp bounds;
- exact derived document identities, stable-identity uniqueness, reference uniqueness, catalog order, ownership, reachability, and orphan documents;
- exactly one available `ai-foundations` program plus valid `comingSoon` shells;
- first-lesson identity, prerequisite reachability/order, missing prerequisite references, and cycles;
- closed block sets, presentation order, completion-rule identity, rubric/question/option scoring references, diagram asset membership, connector references, accessibility text, and rights metadata;
- canonical text, scalar/list bounds, per-document bytes, payload bytes, declared byte count, payload digest, and document digest.

Missing prerequisite IDs now retain both the prerequisite violation and a safe typed `brokenReference` identifier. Repeated use of one declared diagram asset is valid, matching the Node membership contract rather than incorrectly requiring one asset entry per diagram block.

## Canonical JSON and cross-runtime evidence

Swift consumes the six checked-in RFC 8785 vectors, orders object keys by UTF-16 code units, preserves array order and omission/null semantics, emits canonical UTF-8, and computes lowercase SHA-256. Document digests remove exactly `contentDigest` and `publishedAt`; payload digests include the complete payload.

| Shape | Node/Swift golden SHA-256 |
| --- | --- |
| Catalog | `09ee3bde8966cf57e8c06c11e70c818661a30b1344bee08044dcffcda145ac0f` |
| Program | `7da67775c59207f426fd295c3e322644eb3b39b23422aef6858871c01181c170` |
| Module | `fb1206946b1146077ae57ef958d56e3c1c4aefff8baece1a04af7f6802b598c6` |
| Lesson | `1dcc5c24fcc01fe41912750effd9252ff956e7e396c2c2774b5223cab87cfbb8` |
| Public rubric | `955d5ffbab96e7274f64b9b8b22fb835361851975d9c916b0a2325dca1f4819d` |
| Diagram asset | `8eb3f6dfe240e7be691a74c48de572519284e29bace1ae601257bc0140d00515` |
| Diagram payload | `69b953e837b2a1721ea158884fefc2162a65a63497e93731743ceae5f1d78018` |
| Coming-soon program | `fec6dbef628d2f483b343a666c0293869a662344be51a9639994fc8d3d545419` |

The diagram payload is 292 canonical bytes. The full publisher-only publication digest remains `ecfcd967b8824e82c4f1a4ec9c2e9f92ed64b9dd0dddac9cf0b7e06e35ad8834`; it includes the private evaluation document and therefore remains Node-only.

The Node content test compares every learner-readable synthetic projected document, excluding only the server timestamp, with the publisher-generated immutable shape. It also proves the public projection contains no protected evaluation array. A second shared synthetic program proves a valid `comingSoon` shell preserves `firstLessonVersionID: null`, has no module references, matches the golden digest, and validates in catalog order beside Foundations.

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled implementation:

| Gate | Result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 118 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **349 passed** |

The run used iPhone 17 Pro / iOS 26.5. The recurring Xcode `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version` messages remained non-failing tooling warnings; no test was retried, skipped, or masked.

## Toolchain and security evidence

- macOS 26.6.2 (25G83)
- Xcode 26.6 (17F113), Apple Swift 6.3.3, project language mode Swift 6
- XcodeGen 2.46.0
- Node 22.23.2 and npm 10.9.8
- OpenJDK 21.0.12.1
- Firebase CLI 15.28.1
- Gitleaks 8.30.1

The canonical content gate's complete-history and first-party worktree scans were clean. A separate standalone Release simulator build from implementation commit `f3a07ec` contained none of the two synthetic published-client fixtures or the shared digest-vector file. Its direct bundle scan examined approximately 150.10 KB, its extracted strings/normalized-plist scan examined approximately 4.11 MB, and both were clean under the pinned Gitleaks policy. This is strong resource-separation evidence, but it is not a signed App Store archive certification.

## Independent review

Independent contract, harness, and security/performance reviews found and drove fixes for:

- test resources initially missing from the generated project and an invalid zero-test RED claim;
- missing automated public-projection parity and incomplete exact-key/compatibility/issue-code coverage;
- over-restrictive diagram asset multiplicity and URI behavior that differed from Node;
- unconstrained timestamp seconds;
- oversized graph work continuing before bounds rejection and quadratic issue lookup;
- unbounded duplicate-key storage during strict JSON preflight;
- Node accepting decimal/exponent number syntax that Swift rejected;
- oversized payloads receiving a digest diagnostic instead of a size diagnostic;
- missing prerequisites lacking a typed broken-reference signal;
- missing positive coming-soon/null digest coverage;
- private-use locale parsing and repeated BCP 47 variants.

After the fixes, the final independent verdict found no remaining P0, P1, or P2 Task 5 issue. Swift 6 strict-concurrency typechecking passed with warnings treated as errors.

## Deliberate non-claims and open work

- No original learner-facing content was authored.
- No staging or production Firebase write occurred.
- No specialization was selected or inferred; Product must still choose exactly one of School, Work, Creation, or Build through Product Bible change control.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent.
- `content/config/environments.json` remains emulator-only.
- Task 6 is next: the app-owned, environment/project/locale-namespaced atomic cache and quarantine behavior.
- Tasks 7–13 remain open: concrete exact-get repository, store/UI, preview handoff, UI/accessibility fixtures, analytics, approved content/staging enablement, and certification.
- Production-shaped Rules proof, minimum-iOS CI, physical accessibility, signed-release scanning, and named owner approval remain open.

Phase 2 remains in progress, and all Product Bible release gates remain unsatisfied.

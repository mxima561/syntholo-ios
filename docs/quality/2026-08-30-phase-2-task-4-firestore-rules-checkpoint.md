# Syntholo Phase 2 Task 4 Firestore Rules checkpoint

**Date:** August 30, 2026

**Binding specification:** `docs/superpowers/specs/2026-08-25-syntholo-product-bible.md`

**Binding Phase 2 contract:** `docs/superpowers/plans/2026-08-30-syntholo-curriculum-platform.md`, especially Section 4.9 and Task 4

**Implementation commit:** `5e94dc0` (`feat(content): protect exact curriculum reads`)

**Documentation provenance:** introduced by the Task 4 documentation commit recorded in the follow-up provenance update

## Result

Phase 2 Task 4 is complete at emulator scope. The learner client has an authenticated, exact-get-only Firestore Rules boundary for published curriculum documents. Broad queries, all client curriculum writes, private publication data, authoring namespaces, and unknown paths remain denied. The existing profile contract and final catch-all deny are preserved, and no Firestore index was added.

This is not Phase 2 completion or launch approval. It does not prove a live staging deployment, production-shaped Rules behavior, original curriculum, Swift graph/digest parity, cache/repository/UI behavior, a physical-device flow, or any Product Bible release gate.

## Exact allowed surface

An authenticated client may issue an exact `get` for these paths when the existing document satisfies the frozen shallow contract:

1. `featureConfiguration/curriculum`
2. `catalogs/{localeToken}`
3. `catalogVersions/{catalogVersionID}`
4. `programs/{programPointerID}`
5. `programVersions/{programVersionID}`
6. `modules/{moduleVersionID}`
7. `lessonVersions/{lessonVersionID}`
8. `rubricVersions/{rubricVersionID}`
9. `assetVersions/{assetVersionID}`

An exact get of a syntactically allowed but absent document is permitted to resolve as not-found. Rules do not dereference missing `resource.data` and turn that condition into permission-denied.

Every `list` or query is denied, including a document-ID equality query. Every client create, update, and delete is denied across learner-readable documents and the private publication/authoring surface. Private `evaluationContractVersions`, `contentVersionHeads`, `contentPublicationAudit`, authoring records, and unknown namespaces are unreadable to the learner client.

## Shallow validation boundary

Rules enforce only the single-document facts frozen in Section 4.9:

- authentication and exact path identity;
- exact top-level keys;
- top-level types and timestamps;
- schema version, minimum-client version, fixed launch locale, and publication state;
- simple scalar and list bounds;
- stable, pointer, version, and digest text formats;
- the available/coming-soon program relationship that can be proved from one document.

Rules intentionally do not recursively prove nested block/option/node/connector unions, nested uniqueness or ordering, cross-document references, prerequisite reachability, canonical JSON, SHA-256 recomputation, or publication transaction integrity. The trusted Node path proves those before writing. Task 5 must prove every learner-relevant invariant again in Swift before content is rendered or replaces the last valid cache.

## Identifier boundary evidence

Schema v1 is fixed to `en-US` / `en-us`, so the Rules derive the current path limits from the frozen 64-character stable-ID maximum:

| Identifier | Accepted maximum | Rejected next boundary |
| --- | ---: | ---: |
| Stable ID | 64 characters | 65 characters |
| Locale pointer ID | 71 characters | 72 characters when caused by a 65-character stable ID |
| Locale version ID | 84 characters | 85 characters when caused by a 65-character stable ID |
| Version suffix | 10 digits | 11 digits |

Positive tests cover a 64-character pointer and a 64-character stable ID with a 10-digit version. Negative tests cover 65-character stable IDs and 11-digit catalog and generic version suffixes. A future locale or schema expansion must change the normative contract and tests rather than silently widening these launch Rules.

## Test-first evidence

The initial command was:

```bash
./scripts/test_firebase_rules.sh
```

Against the previous catch-all curriculum policy, the expanded 31-test body produced the intended RED result: 28 passed and 3 failed. The failures were the three positive behaviors the old Rules could not provide:

1. authenticated exact gets of valid published curriculum;
2. allowed missing-path exact gets returning not-found;
3. a valid shallow document remaining readable even when deeper nested validation is outside Rules.

After the Rules implementation, all 31 test bodies passed while the runner still failed closed on its old expected count of 20. Updating the exact expected count to the observed complete total was therefore a separately exercised guard change, not a relaxed assertion.

The settled focused command was:

```bash
git diff --check && zsh -lic './scripts/test_firebase_rules.sh'
```

Result: 31 passed, 0 failed, 0 cancelled, and 0 skipped using Firebase CLI 15.28.1, Java 21, and an isolated Firestore emulator port that was shut down after the run.

The exact composition is 20 preserved profile tests plus 11 curriculum tests:

| Curriculum test | Contract proved |
| --- | --- |
| Valid authenticated exact gets | All nine learner-readable document shapes are reachable only by exact get. |
| Allowed missing exact paths | Absence resolves as not-found instead of permission-denied. |
| Unauthenticated exact gets | Authentication is required for every learner curriculum path. |
| Collection and document-ID queries | Every list/query shape is denied. |
| Published state and nested boundary | Drafts fail; a shallow-valid/deep-malformed record demonstrates that deeper validation remains outside Rules. |
| Path/document identity | Mismatched and malformed IDs fail. |
| Exact top-level keys | Unknown and missing top-level keys fail for every shape. |
| Schema and type checks | Unsupported schemas and wrong top-level types fail. |
| Scalar/list bounds | Frozen simple bounds, including ID edges, are enforced. |
| Private/authoring/unknown reads | Evaluation, audit, heads, authoring, and unknown namespaces fail. |
| Client mutations | Create, update, and delete fail across public and private curriculum surfaces. |

## Canonical gate

One uninterrupted `./scripts/test.sh` invocation completed after the settled Task 4 implementation:

| Gate | Result |
| --- | ---: |
| Curriculum content contract | 73 passed, 0 failed, 0 cancelled, 0 skipped |
| Operator identity | 32 passed, 0 failed, 0 cancelled, 0 skipped |
| Publication/rollback lifecycle | 38 passed, 0 failed, 0 cancelled, 0 skipped |
| Swift unit tests | 106 passed, 0 failed, 0 skipped |
| Functional UI journeys | 18 passed, 0 failed, 0 skipped |
| AppShell accessibility audits | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility audits | 11 passed, 0 failed, 0 skipped |
| Firestore Rules | 31 passed, 0 failed, 0 cancelled, 0 skipped |
| **Aggregate** | **337 passed** |

The run used iPhone 17 Pro / iOS 26.5. The recurring Xcode `DebuggerLLDB.DebuggerVersionStore.StoreError` / `no debugger version` messages remained non-failing tooling warnings; no test was retried, skipped, or masked. The canonical pre-test Gitleaks 8.30.1 history and first-party worktree scans were clean.

## Independent review

Three independent read-only reviews covered the settled implementation:

- Contract review found the exact-get/list/write boundary, shallow validation split, preserved profile tests, empty index file, and exact test count aligned with Task 4.
- Security review found one low-severity version-suffix issue in an intermediate Rules draft. Both version regexes were restricted to 1–10 digits, and 11-digit rejection coverage was added.
- Rules-semantics review found an intermediate stable-prefix length gap. An independent 3–64-character stable-prefix guard and exact boundary tests fixed it. The final review verdict was clean and found no test passing for the wrong reason.

No authentication, list/query, private-read, write, or catch-all bypass remains in the reviewed Task 4 scope.

## Deliberate non-claims and open work

- No original learner-facing content was authored.
- No staging or production Firebase write occurred.
- No specialization was selected or inferred; Product must still choose exactly one of School, Work, Creation, or Build through Product Bible change control.
- `content/config/launch-content-decision.json` and `content/drafts/ai-foundations-v1.json` remain absent.
- `content/config/environments.json` remains emulator-only.
- Production-shaped staging Rules proof, minimum-iOS CI, physical accessibility, and named owner approval remain open.
- Task 5 is next: Swift identifiers/models, canonical JSON/digest parity, validation, and the `AsyncStream<CurriculumLoadEvent>` boundary.
- Tasks 6–13 remain open: cache, repository, store/UI, preview handoff, UI/accessibility fixtures, analytics, approved content/staging enablement, and certification.

Phase 2 remains in progress, and all Product Bible release gates remain unsatisfied.

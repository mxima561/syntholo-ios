# Phase 2 Task 3 publication checkpoint

**Date:** August 30, 2026

**Scope:** Emulator-only idempotent curriculum publication and rollback, operator identity, transaction integrity, and exact-source security controls

**Phase status:** In progress; this checkpoint does not satisfy the Phase 2 content-load or exit gate

**Implementation commit:** `ec8ac97` (`feat(content): add atomic emulator publisher and rollback`)

**Initial documentation checkpoint commit:** `c6cab41` (`docs: record Task 3 publication checkpoint`)

## Outcome

Task 3 is implemented and independently reviewed at emulator scope against Task 3 and Sections 4.7 and 5.1–5.3 of the frozen curriculum-platform contract. The implemented interface is intentionally incapable of a live content write: its only environment is the exact local tuple `emulator / syntholo-local / emulator / emulator-local`, production is disabled, and the command path constructs only a loopback Firestore-emulator client.

No original learner-facing curriculum was authored, no staging or production project identity was added, no launch-content decision record was created, and no staging or production content write was attempted. The only publication input used by this checkpoint is the unmistakably synthetic fixture under `tests/fixtures/content/`.

The implementation now provides:

- Strict, closed environment and launch-decision configuration, with an emulator-only allowlist and a derivative decision schema that cannot override an unresolved Product Bible decision.
- Mutually exclusive `--dry-run` and `--apply` modes; explicit canonical operation ID, environment, project, and project confirmation; optional non-authorizing `requestedBy`; and bounded, redacted command output.
- Exact resolved-source scanning with the repository-pinned Gitleaks policy before Firebase Admin import or construction, followed by a private, read-only sealed-byte snapshot that is scanned again and is the authoritative parse input.
- A fixed loopback emulator identity that never asks for live ADC, forbids REST transport fallback, rejects caller-supplied principals, and fails closed for unknown, staging, or production command contexts.
- One catalog-rooted Firestore transaction for publication, with transaction-local revalidation, exact immutable/private shapes, create-only immutable documents, concurrency-safe version heads, deterministic request/publication digests, replay/collision handling, complete pointer/configuration updates, and an immutable audit for both applied and no-op outcomes.
- One catalog-rooted rollback transaction that reconstructs and validates the complete pinned target graph and every corresponding historical head, changes only pointers/configuration plus the audit, writes exactly one audit for a new no-op request, and never creates, rewrites, deletes, or lowers immutable history.
- Dynamic isolated Firestore, websocket, hub, and logging ports, exact TAP-count enforcement, listener-closure proof, and integration into `package.json`, `scripts/test_content.sh`, and the canonical `scripts/test.sh` gate.

## RED evidence

The implementation followed a RED/GREEN sequence. The initial Task 3 lifecycle and authorization tests were introduced against the absent/incomplete operator path and failed before the publisher, rollback tool, identity resolver, transactions, and runner satisfied their contracts. The RED cases covered first publish, version-head creation and advance, historical monotonicity, exact no-op auditing, immutable collision, non-live selection rejection, replay after later state changes, operation-ID collision, roll-forward, exact rollback, repeated rollback, transaction budget, and injected-failure atomicity.

The independent security review then supplied deterministic regressions that reproduced each of the five findings below before its fix. Those regressions remain in the focused suites; strengthening them did not inflate the final top-level publication count because related assertions were kept within the owning lifecycle cases.

## Focused GREEN evidence

The settled Task 3 tree passed:

- Curriculum schema, graph, digest, bounds, budget, CLI, and shape tests: **73/73**, with zero failures, cancellations, or skips.
- Operator environment, decision, emulator, and derived-identity tests: **32/32**, with zero failures, cancellations, or skips.
- Emulator publication/rollback lifecycle and security tests: **38/38**, with zero failures, cancellations, or skips.

The focused subtotal is **143 passing tests**. The publication runner used pinned Firebase dependencies and Java 21, allocated four non-default ephemeral ports, and proved that Firestore, websocket, hub, and logging listeners were all closed after the suite. Node syntax checks and `git diff --check` also passed. The focused content gate completed its full-history/worktree secret scan successfully.

**Verification environment:** macOS 26.6.2 (25G83), Xcode 26.6 (17F113), XcodeGen 2.46.0, iPhone 17 Pro simulator on iOS 26.5, Node 22.23.2, npm 10.9.8, Java 21.0.12.1, Firebase CLI 15.28.1 with Firestore emulator 1.22.0, and Gitleaks 8.30.1.

**Uninterrupted canonical totals:** The final `./scripts/test.sh` invocation passed 73 curriculum-content, 32 operator-identity, 38 publication/rollback, 106 Swift unit, 18 functional UI, 28 AppShell accessibility, 11 onboarding accessibility, and 20 Firestore Rules tests—**326 total**, with zero failure, skip, or cancellation.

**Pre-documentation bundle scan:** Gitleaks 8.30.1 passed complete history (five commits total, including the implementation commit), the first-party worktree, the 304.22 KB generated `DerivedData/Build/Products/Debug-iphonesimulator/Syntholo.app`, the direct app bundle, and 3.44 MB of extracted strings/normalized plists with no leak.

A separate diagnostic scan of the entire 1.04 GB `DerivedData` tree reported 93 redacted matches. Path/rule triage assigned all 93 to downloaded Firebase/gRPC/GoogleSignIn source, dependency test fixtures/code signatures, or copied third-party private headers. No match was in first-party source or the shipping app. This distinction is recorded rather than suppressing or misreporting the whole-tree result.

The first attempted canonical invocation disclosed a SpringBoard `Busy` preflight denial before the first Practice audit body launched. The identical audit passed after explicit simulator boot readiness. The harness was then hardened to derive the exact simulator ID from the passed functional result, pin every accessibility destination to it, and perform a fail-closed boot-wait → targeted shutdown → boot-wait before Learn, Practice, Social, Profile, and onboarding. The next complete invocation passed all 28 AppShell audits—including Social hit-region—and the full 326-test gate without retrying or masking a test failure.

## Security findings and fixes

The independent security review identified five concrete findings. All five were fixed and have deterministic regression coverage:

1. **REST fallback could consult ambient ADC in emulator mode.** The command now rejects a forced REST preference, constructs Firestore with `preferRest: false`, uses only the exact emulator project tuple, and proves poisoned ambient Google credential state cannot be consulted by the accepted emulator path.
2. **The first source scan was vulnerable to a scan-to-parse replacement race.** Publish still scans the exact resolved source path before Firebase is available, then reads through a no-follow file descriptor, writes the exact bytes to a private read-only snapshot, scans that snapshot, verifies its bytes are unchanged, and parses only the captured authoritative bytes.
3. **Foreign SDK/filesystem failures could cross the diagnostic boundary.** Only repository-owned error classes may contribute bounded error codes and JSON-pointer paths. Foreign errors collapse to a fixed `PUBLICATION_REJECTED` issue; raw messages, filesystem paths, credential locations, and foreign `exitCode` values are not trusted, including a forged zero exit code.
4. **Missing-head history checks trusted mutable stored identity fields and used a weak prior upper bound.** Historical presence is now determined from the authoritative document ID, using the exact identity prefix with an inclusive `...--v` lower bound and exclusive `...--w` upper bound. The regression includes a corrupt `v\uFFFF` suffix and injects `FieldPath.documentId()` so it exercises the real range query.
5. **Arbitrary emulator hosts could redirect the trusted operator path off machine.** Emulator publication now accepts only an explicit `127.0.0.1:<valid-port>` endpoint and rejects hostnames, non-loopback IPs, missing hosts, and invalid port ranges before Firestore construction.

The final security verdict is **no open finding within the emulator-only Task 3 scope**. The controls prove that the accepted path scans the bytes it parses, cannot escape the local emulator or silently consult ambient live credentials, fails closed on corrupt history, and does not expose foreign diagnostic data.

## Independent contract verdict

The independent acceptance audit compared every Task 3 requirement and Sections 4.7 and 5.1–5.3 against the settled config, tools, tests, package scripts, canonical gate, and Firebase setup documentation. It found **zero substantive missing or overclaimed implementation items at emulator scope**.

The audit specifically confirmed the exact trusted-private evaluation/head/audit shapes; catalog-rooted publish and rollback; replay-before-current-state behavior; full immutable-shape comparison; create-only immutable writes; historical maxima across rollback; strict same-live no-op behavior; pointer/configuration/audit atomicity; rollback graph reconstruction; safe output; exact-source scan ordering; dynamic-port isolation; exact focused totals; package/canonical-gate integration; and the documented `127.0.0.1:8080` interactive emulator endpoint.

Task 3 may therefore be marked **implemented at emulator scope**. This contract verdict does not authorize staging, satisfy Task 4 or later curriculum tasks, or complete Phase 2; the separate canonical-gate evidence above establishes only the current local baseline.

## Product stop and open gates

The Product Bible still asks which one of School, Work, Creation, or Build is the first fully built specialization. Engineering did not infer an answer.

The mandatory stop remains intact:

- `content/config/launch-content-decision.json` does not exist.
- `content/drafts/ai-foundations-v1.json` does not exist.
- `content/config/environments.json` contains no staging or production identity.
- The CLI has no live Firestore construction path; production is explicitly rejected.
- No original Foundations/specialization lesson, specialization shell, staging content, staging-device load, or Phase 2 exit evidence was created by Task 3.

Original curriculum authoring and every staging or production content write remain blocked until Product records the dated specialization through Product Bible change control, the tracked derivative decision matches it, environment owners provide the exact approved staging project and keyless impersonated publisher principal, and the named owners authorize the load.

Still open after this checkpoint are curriculum Firestore Rules, Swift domain/digest parity, app-owned cache, exact-get repository, observable store and read-only preview UI, navigation, localization/accessibility/analytics, original reviewed content, staging publication/rollback proof, and Phase 2 exit approval.

## Known limitations

- This is emulator-only proof. The pure identity library tests keyless-derived staging authorization semantics, but no real ADC/IAM impersonation, authenticated Google project metadata lookup, least-privilege live role, staging Firestore construction, or Cloud Audit Log evidence exists yet.
- The publication tests exercise trusted Admin transactions; learner read/write protection remains Task 4 and must be proven separately with exact Firestore Rules tests.
- The focused Node/emulator gates do not prove Swift graph parity, cache/repository behavior, UI loading, physical-device accessibility, minimum-iOS CI, staging-device behavior, or release readiness.
- The synthetic fixture proves structure and transaction behavior only. It is not approved launch curriculum and cannot satisfy the Product Bible content gate.
- Task 3 does not certify a signed release archive, App Check, live provider configuration, production monitoring, or operational rollback ownership.

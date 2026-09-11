# Phase 2 Task 2 validation checkpoint

**Date:** August 30, 2026

**Scope:** Synthetic schema, pure validation, deterministic publication shapes, and secret-scanning foundation only

**Phase status:** In progress; this checkpoint does not satisfy the Phase 2 exit gate

**Implementation commit:** `7b76f87`

## Outcome

Task 2 is implemented and verified against the frozen curriculum-platform contract. No original learner-facing curriculum was authored, no Firebase client was constructed by the pure validation path, and no staging or production content write was attempted.

The implementation now provides:

- Draft 2020-12 JSON Schema definitions for the authoring envelope and all seven immutable pre-server publication shapes, catalog/program pointers, feature configuration, version heads, publication audits, and program selections.
- A clearly synthetic seven-document fixture containing the reserved non-publish sentinel in a learner-visible title.
- RFC 8785 canonical JSON vectors and deterministic payload, document, and publication SHA-256 digests.
- Structured, fail-closed validation for IDs, locale/version identity, exact keys, scalar/array/byte bounds, graph reachability, ordering, prerequisite DAGs, assets/rights/accessibility, public/protected scoring agreement, document limits, publication size, and the frozen transaction budget.
- Safe CLI parsing for fatal UTF-8, duplicate keys, unknown properties, and redacted diagnostics.
- A checksum- and version-verified Gitleaks 8.30.1 installer and gate covering complete non-shallow local history, ignored and non-ignored first-party worktree files, generated output, direct bundle contents, extracted binary strings, and normalized binary/XML plists.

## Test evidence

The curriculum suite passed **73/73**, with zero failures, cancellations, or skips. The valid fixture produced:

```text
catalogVersionID: catalog--en-us--v1
immutableDocumentCount: 7
canonicalDocumentBytes: 4976
calculatedTransactionUnits: 36
publicationDigest: ecfcd967b8824e82c4f1a4ec9c2e9f92ed64b9dd0dddac9cf0b7e06e35ad8834
```

The secret-scanner regression proved a clean scope and rejected malicious target configuration, inline allow annotations, ignored and non-ignored worktree credentials, non-Git and shallow-history misuse, a secret deleted from current HEAD but retained in history, compiled Mach-O credentials, binary-plist credentials, and bundle symlinks.

Real local scans were clean:

- Git history: 2 commits; 937,199 bytes examined.
- Observed final-report checkpoint worktree snapshot: 1,575,098 bytes examined.
- Generated portable report: 472,180 bytes examined.
- Existing simulator app: 304,217 direct bytes plus 3,444,744 extracted binary/plist bytes examined.

Fresh aggregate app evidence reached:

- Curriculum content: 73 passed.
- Swift unit: 106 passed.
- Functional UI: 18 passed.
- AppShell accessibility: 28 passed.
- Onboarding accessibility: 11 passed.
- Firestore Rules: 20 passed.

The uninterrupted canonical invocation encountered one anomalous 112-second failure in `testSocialHitRegionAudit`. That test then passed three consecutive isolated reruns in 23.7–26.9 seconds, and the remaining accessibility and Rules checks passed in the resumed gate. Another uninterrupted `./scripts/test.sh` run is required before merge.

## Toolchain and dependency posture

- Xcode 26.6; local iOS 26.5 simulator.
- Swift 6.3.3 and XcodeGen 2.46.0.
- Node 22.23.2 and npm 10.9.8.
- Java 21.0.12.1, Firebase CLI 15.28.1, and Gitleaks 8.30.1.
- `npm audit`: 9 moderate development-tooling findings, 0 high, 0 critical.
- `npm audit --omit=dev`: 0 production findings.

Minimum-iOS 17 remains CI-only on this machine.

## Open gates

Task 3 must now implement the emulator-only idempotent publisher and rollback path. It must verify native Firestore timestamps and transactional version-head/audit cross-field invariants, scan the exact source with the pinned scanner before Firebase construction, and prove replay, collision, no-op, rollback, and atomicity semantics.

Still open after Task 3 are curriculum Firestore Rules, Swift domain/digest parity, app-owned cache, exact-get repository, observable store states, preview UI/navigation, localization/accessibility/analytics, owner approval, and staging proof.

The content-load gate remains closed until Product records School, Work, Creation, or Build in the Product Bible and the environment owner supplies the approved staging project identity and keyless publisher principal.

## Known limitations

- The clean app scan covered a debug simulator `.app`, not the final signed release archive.
- Nested archives are not expanded; any introduced archive requires bounded extraction and an explicit scan.
- A narrowly reviewed exception may be needed later for confirmed public Firebase client metadata; credentials and provider secrets may never be allowlisted.
- No Git remote is configured, so upstream history, branch protection, and remote CI provenance are unverified.
- XcodeGen still comes from a moving Homebrew formula and CI action references use moving major tags; these remain reproducibility-hardening tasks.

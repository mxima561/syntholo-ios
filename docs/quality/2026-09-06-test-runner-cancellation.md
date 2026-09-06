# Test-runner cancellation checkpoint

**Date:** September 6, 2026 (America/New_York)

**Authority:** [Launch completion master plan](../superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md), Stage 0; [Product Bible](../superpowers/specs/2026-08-25-syntholo-product-bible.md).

**Scope:** Cancellation/evidence correctness in PR #3. This is not completion of Phase 1, Phase 2, or any launch gate.

**Outcome:** The corrected runner at `c25791f` passed the complete current-runtime gate: **487/487**, exit 0, zero failed/skipped/cancelled tests, and no runtime retry. Required remote CI and owner-controlled product gates remain open.

## Review finding and correction

A fresh [CodeRabbit review](https://github.com/mxima561/syntholo-ios/pull/3#pullrequestreview-5124112557) of `f83eb0d` through `99ad68c` identified a real [Major cancellation defect](https://github.com/mxima561/syntholo-ios/pull/3#discussion_r3942935735). Terminating the canonical runner could leave its timeout wrapper and isolated command group alive. The old regression manually killed the child after the runner exited, so it did not prove cleanup.

Implementation commit `5189f8b049c519f85cb4d03f4409cc3554eee590`:

- Adds a narrowly owned asynchronous timeout-wrapper helper. HUP, INT, and TERM cancel and wait for that exact wrapper PID; the wrapper terminates its own isolated command group. Parent exit statuses remain 129, 130, and 143. A pending-signal guard covers helper launch/PID registration.
- Routes all formerly timed operations through the helper. The seven formerly unbounded preflight stages now also use the helper with a 600-second cap, preventing Bash from deferring cancellation while a foreground content or harness check runs. Publication remains 300 seconds; existing build, test, reboot, and Rules deadlines are unchanged.
- Makes wrapper cleanup tolerate repeated signals, explicitly reap the command, and terminate/reap the watchdog's owned polling sleep.
- Replaces the cancellation fixture with the real runner and real timeout wrapper in an isolated synthetic checkout. It asserts prompt parent termination, correct status, evidence retention when results exist, and no surviving recorded child/wrapper **before** fallback cleanup. Preflight cancellation must not proceed into XCTest.
- Fixes watchdog regressions that previously wrote empty PID files under macOS Bash 3.2, where `BASHPID` is unavailable. Fixtures now record and validate real numeric process IDs.

No application code, Swift test, test-count requirement, accessibility exemption, or retry eligibility changed. This does not claim cleanup of arbitrary detached processes or uncatchable SIGKILL.

## Red/green and independent review

Before the production fix, the strengthened real-wrapper case failed with `Runner cancellation left its active child running.` The separate preflight regression failed with `Runner TERM handling waited for the active child instead of terminating.` Repeated-signal watchdog tests also failed because the watchdog process group survived.

After the fix:

- All 11 failure-evidence cases pass: unit failure, Rules failure, successful cleanup, three self-signals, closed stderr, real active-child HUP/INT/TERM, and preflight TERM. Unit-stage cancellation preserves the partial bundle and prints its path; preflight cancellation starts no XCTest work.
- Watchdog tests pass for timeout 124, command status 7, repeated TERM, and process-group TERM; the owned command and wrapper/watchdog groups are gone before test cleanup.
- Timeout-only retry, diagnostics, reboot failure, path/cleanup guards, XCTest/TAP result-assertion regressions, static CI workflow contract checks, shell syntax, and whitespace checks pass. These harness checks are not executed application suites or remote CI jobs.
- Independent read-only review found the preflight ownership gap and a fixture readiness race; both were corrected. No further demonstrated production ownership/trap/exit defect was reported.
- Gitleaks 8.30.1 passed complete Git history, worktree, generated project, app bundle, and extracted binary/plist strings.

Local logs retain the observed red/green evidence:

- `/tmp/syntholo-cancellation-99ad68c-isolated-real-wrapper-red.log`
- `/tmp/syntholo-cancellation-preflight-red.log`
- `/tmp/syntholo-cancellation-final-evidence-green.log`
- `/tmp/syntholo-cancellation-nested-harness-red.log`
- `/tmp/syntholo-cancellation-nested-harness-green.log`

The first integrated invocation at `5189f8b` failed in preflight, before any real XCTest, because a self-signal fixture inherited ignored INT through its new background watchdog. Its printed XCTest counts came from the synthetic fixture and are not application evidence. Follow-up commit `eca40dbde5eb934e649a1a28b3cb513b042e7cd7` restores default INT through Perl before the fixture's Bash entrypoint, matching its foreground-signal premise. The expected 130 assertion remains unchanged. All 11 cases then passed through a real **background** watchdog, and the narrow fix was independently reviewed. The failed attempt's log and exit-1 manifest remain in `/tmp/syntholo-cancellation-canonical.w3NzMW/`.

## Full current-runtime verification

A second invocation at executable source `eca40db` also stopped in preflight, with exit 141 and no real XCTest execution. The watchdog fixture's `ps | awk` lookup exited its consumer early under `pipefail`, making upstream SIGPIPE a flaky harness failure. Its log and manifest remain in `/tmp/syntholo-cancellation-canonical.zy7aax/`. Follow-up commit `c25791f9bd550629b4ab22a59eacf44095298d14` preserves first-match selection while consuming the whole process listing. The watchdog suite then passed five consecutive background-wrapper runs, and a separate combined run passed all five harness suites through real background wrappers.

The final invocation at `c25791f` completed uninterrupted from **05:09:49.987 to 05:38:44.417 UTC** (01:09–01:38 local). Executable source stayed unchanged throughout; only this report was drafted during execution. The actual target was Syntholo Canonical iPhone 17 Pro / iOS 26.5 build 23F77, UDID `DE03DC0C-47B0-44C1-AB3D-B0D35CE5213D`, using Xcode 26.6 build 17F113 / SDK 26.5 on macOS 26.6.2 build 25G83. Node was 22.23.2 and Homebrew OpenJDK was 21.0.12.1. The Build iOS Apps workflow separately built/launched the app and the rendered welcome screen was inspected before the canonical invocation.

```bash
env -u SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT \
  SYNTHOLO_DESTINATION='platform=iOS Simulator,id=DE03DC0C-47B0-44C1-AB3D-B0D35CE5213D' \
  ./scripts/test.sh
```

A passive local collector invokes that unchanged command, preserves its exit status and full output, and copies each completed XCTest bundle after the runner's own successful result assertion. It does not alter tests, retry rules, or simulator state. The current invocation's output is under `/tmp/syntholo-cancellation-canonical.Ix1wV6/`; the manifest records exact source, start/end time, canonical status, and copied bundles. Successful-run cleanup remains enabled.

| Counted suite | Passed |
| --- | ---: |
| Curriculum content | 73 |
| Operator identity | 32 |
| Publication/rollback | 38 |
| Swift unit | 232 |
| Functional UI | 28 |
| AppShell accessibility | 28 |
| Curriculum accessibility | 14 |
| Onboarding accessibility | 11 |
| Firestore Rules | 31 |
| **Total** | **487** |

The canonical process and collector both exited 0. All 47 copied bundles were independently reopened with `xcresulttool`: 313 XCTest passes, zero failed/skipped/expected failures, and the exact same iOS 26.5 device/build throughout. Four TAP summaries account for the remaining 174 passes, with zero failures/skips/cancellations. A separate reviewer independently confirmed the first 32 completed bundles (288 passes) before the final all-bundle verification. No runtime test retried or opted out of accessibility; synthetic retry messages in preflight are deliberately failing harness fixtures, not runtime failures.

Evidence retained locally: `canonical.log`, `manifest.json`, `verified-summaries.json`, all 47 `bundles/*.xcresult`, and `secret-scan.log` in the directory above. These are local temporary artifacts, not uploaded GitHub CI evidence. The failed preflight attempts remain separately preserved rather than being relabeled as passes.

The prior [current-runtime baseline](2026-09-06-current-runtime-baseline.md) and [iOS 17.5 baseline](2026-09-05-baseline-ci-verification.md) remain historical evidence for their recorded revisions. The iOS 17.5 application code is unchanged, but its older run does **not** prove this new runner or GitHub's separate Xcode 16.2 lane.

## Delivery and product boundaries

At the pre-push read-back, PR #3 remains open at `99ad68c`; [run 34011494986](https://github.com/mxima561/syntholo-ios/actions/runs/34011494986) has failed `test` and `test-ios-17` jobs with zero executed steps. The freshly read API annotation reports failed account payments or a spending limit that needs increasing. Remote checks must be refreshed on the pushed final head; local passes cannot replace those jobs. Merge PR #3 with a merge commit only after both required jobs and all other final-head checks pass and final automated review is complete. PR #4 remains open at `a8cb4c0`, based on the baseline branch; preserve it until #3 lands and verify its integration afterward.

The app still provides onboarding and a read-only curriculum preview, not the complete lesson/answer/feedback/progress loop. The unchanged mandatory content-load gate is 0/4: accepted specialization, matching tracked decision record, approved staging identity/keyless publisher principals, and original-content/staging-load authorization are missing. Six-owner Phase 2 contract approval and the separate daily-goal Product contract also remain open. The master plan's dependency order and all four launch gates remain binding.

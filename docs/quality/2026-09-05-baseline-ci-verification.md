# Baseline delivery and iOS 17 verification

**Date:** September 5, 2026 (America/New_York)

**Authority:** [Launch completion master plan](../superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md), Stage 0; [Product Bible](../superpowers/specs/2026-08-25-syntholo-product-bible.md), `LAW-12`, `LAW-18`, `SHIP-A11Y`.

**Outcome:** The final local iOS 17.5 canonical run passed all 487 counted tests without failure, skip, cancellation, or runtime retry. The complete onboarding accessibility class also passed 11/11 on iOS 26.5. Required remote CI and launch gates remain open.

**Subsequent checkpoint:** [September 6 current-runtime verification](2026-09-06-current-runtime-baseline.md) records a new full 487/487 iOS 26.5 invocation at the same executable source. The historical scope of this September 5 report is unchanged.

## Scope and source

The baseline is preserved in [PR #3](https://github.com/mxima561/syntholo-ios/pull/3), branch `codex/baseline/launch-readiness-reconciliation`. The original full-run application and UI-test source was `f83eb0da9e87f08bfcdfaa036b00cdf819d0cf47`; subsequent onboarding corrections are described below. [PR #4](https://github.com/mxima561/syntholo-ios/pull/4) separately preserves restored-session sign-out recovery at `a8cb4c0a9a8ec1eb983dc4e391725ddf7ab1da54`.

This checkpoint does not complete Phase 1, Phase 2, or any launch gate. The app still renders a read-only curriculum preview; real lesson execution and the later launch phases remain incomplete.

## Accessibility failure and fix

The original preview contrast failure reproduced on iPhone 15 Pro geometry under both iOS 17.5 and iOS 26.5. Positioning the diagram card partly occludes the earlier objective label below the fixed navigation bar. That label passes when its own card is audited. The issue is therefore not evidence of an iOS-17-only color failure.

Commit `f83eb0d` handles only a contrast issue matching the exact synthetic objective identifier and label, the diagram's fully-visible audit context, valid positive element/target/viewport frames, no target-card intersection, and partial occlusion across the viewport's top boundary. Unknown issues, other audit types, invalid frames, and issues within the target card continue to fail. Diagnostics are retained for handled and reported issues; reported failures also retain screenshots.

Fresh focused contrast runs passed 1/1 on each runtime. The full iOS 17 run has also passed contrast; its exported attachment contains exactly one handled issue with identifier `curriculum.lesson.preview.objective`, context `curriculum.diagram.synthetic-diagram-block:fully-visible`, target frame `(20, 524.3333, 353, 326.3333)`, and viewport `(4, 127, 385, 721)`.

The final-source canonical run independently passed this same contrast method at `a2b2867`. Its exported diagnostic at `/tmp/syntholo-baseline-ios17-a2b2867-contrast-attachments/3A649B03-F633-433C-90C8-073B022C6CDC.txt` again contains exactly one `ignored-known-occluded-neighbor` disposition, with the expected objective identifier/label and diagram scope. There were no other audit attachments for that passing method.

## Onboarding Dynamic Type corrections

The unchanged `testSelectionAndAccountLayoutsPassAccessibilityAudits` exposed two production layout defects in sequence:

1. `ChoiceListView` reserved an icon column, spacer, and trailing indicator beside large text. The maximum-size capture showed the experience title split into four fragments and the scaled decorative icon crowding the text. At accessibility sizes, the row now places its decorative icon and indicator above full-width title/detail text, preserving one native Button, the same identifiers, combined accessibility label, and selection traits. Standard text sizes retain the horizontal layout. The original audit then passed the experience screen and advanced to the path screen.
2. The route graphic's `AI FOR SCHOOL` text visibly truncated to `AI FOR SCHO…` at maximum size. Vertical `fixedSize` on that text allows the proposed width to wrap into a second line instead. The original selection/account audit then passed every screen through the native Apple account control.

Commit `a2b2867adf6d1d0dc3576b2a260afcf145117137` contains both production corrections. No audit type, test assertion, or production font size was weakened. The existing audit supplied the regression coverage: original source failed on the experience title, the choice-only correction failed on the route label, and both corrections passed. Independent SwiftUI review found no actionable issue in either correction.

Retained focused evidence:

- `/tmp/syntholo-onboarding-selection-ios17-f83eb0d.xcresult`: original test failed on `Beginner-friendly`.
- `/tmp/syntholo-onboarding-selection-ios17-adaptive.xcresult`: original test advanced past experience and failed on `AI FOR SCHOOL`; temporary screenshot diagnostic passed.
- `/tmp/syntholo-onboarding-path-maximum-type-diagnostic.xcresult`: maximum-size before-fix route screenshot visibly contains an ellipsis.
- `/tmp/syntholo-onboarding-selection-ios17-adaptive-routefix.xcresult`: original audit passed, and temporary screenshot diagnostic passed; zero failed/skipped. The after-fix route screenshot wraps completely to `AI FOR` / `SCHOOL`.

The temporary screenshot-only diagnostic was removed after inspection; it is not counted as a new accessibility gate or permanent test. Canonical test counts remain unchanged. The complete onboarding accessibility class then passed 11/11 with zero failed/skipped on iPhone 15 Pro / iOS 26.5, retained at `/tmp/syntholo-onboarding-ios26-final-layout.xcresult`.

## Final local canonical verification

**Passed:** One uninterrupted invocation at application/runner commit `a2b2867adf6d1d0dc3576b2a260afcf145117137` completed on September 5 with exit 0. Only the documentation checkpoint was being edited during this run; application, test, runner, and configuration source remained unchanged.

```bash
env -u SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT \
  SYNTHOLO_DESTINATION='platform=iOS Simulator,id=4C8AAC0B-DB8F-432E-8788-CEEB11D3CB71' \
  ./scripts/test.sh
```

| Counted suite | Final result |
| --- | --- |
| Curriculum content | 73 passed |
| Operator identity | 32 passed |
| Publication/rollback | 38 passed |
| Swift unit | 232 passed |
| Functional UI | 28 passed |
| AppShell accessibility | 28 passed |
| Curriculum accessibility | 14 passed |
| Onboarding accessibility | 11 passed |
| Firestore Rules | 31 passed |
| **Total** | **487 passed; zero failed, skipped, or cancelled** |

No actual runtime retry occurred. The deliberate synthetic watchdog/retry fixtures are separate harness regressions and do not represent a retry of a canonical UI test. The known Xcode debugger-version warning remained tooling noise; no test was skipped to accommodate it.

The full terminal log is `/tmp/syntholo-baseline-ios17-a2b2867-canonical.log`. A passive collector copied all 47 completed XCTest bundles before successful-run cleanup to `/tmp/syntholo-baseline-ios17-a2b2867-evidence/`. Independent reads of every saved summary confirmed 313 XCTest passes, zero failed/skipped/expected-failure tests, and the same iOS 17.5 device throughout; the remaining 174 passes are the counted content, identity, publication, and Rules suites. These are local temporary artifacts, not uploaded CI evidence. Current-runtime evidence for these onboarding corrections is the 11-test class above, not a claim of a new full iOS 26.5 canonical run.

Local toolchain: macOS 26.6.2, Xcode 26.6 build 17F113 / SDK 26.5, iPhone 15 Pro / iOS 17.5 build 21F79, Node 22.23.2, Homebrew OpenJDK 21.0.12.1. This proves minimum-runtime behavior locally, not the separate CI-pinned Xcode 16.2 / SDK 18.2 toolchain.

Final Gitleaks 8.30.1 checks passed for complete Git history, worktree, generated project, and built app including extracted binary/plist strings:

```bash
./scripts/scan_secrets.sh --history --worktree \
  --generated Syntholo.xcodeproj \
  --bundle DerivedData/Build/Products/Debug-iphonesimulator/Syntholo.app
```

No secret was found in any requested scope. `git diff --check` passed; the final follow-up after `a2b2867` changes documentation only.

## Original local canonical verification

**Historical result: failed at onboarding accessibility. The focused correction above does not turn this failed invocation into a completed canonical pass.**

The run exited 65 after `testSelectionAndAccountLayoutsPassAccessibilityAudits` reported `Text clipped` at `OnboardingUITests.swift:749`. It used no runtime retry. All preceding counted suites passed, and the onboarding class reported 10 passed, 1 failed, 0 skipped. The terminal failure prevented the final Firestore Rules suite from starting.

| Counted suite | Result |
| --- | --- |
| Curriculum content | 73 passed |
| Operator identity | 32 passed |
| Publication/rollback | 38 passed |
| Swift unit | 232 passed |
| Functional UI | 28 passed |
| AppShell accessibility | 28 passed |
| Curriculum accessibility | 14 passed |
| Onboarding accessibility | 10 passed, 1 failed |
| Firestore Rules | Not reached in this invocation |

The full-run cleanup removed its failing onboarding bundle. An isolated reproduction retained `/tmp/syntholo-onboarding-selection-ios17-f83eb0d.xcresult` and confirmed the same failure (0 passed, 1 failed, 0 skipped). Its exported screenshot and element attachment identify the `Beginner-friendly` title on the experience screen. Adding vertical `fixedSize` to that title alone did not fix the original audit and was reverted before the adaptive-layout correction described above.

Run from the baseline worktree:

```bash
SYNTHOLO_DESTINATION='platform=iOS Simulator,id=4C8AAC0B-DB8F-432E-8788-CEEB11D3CB71' ./scripts/test.sh
```

Toolchain: macOS 26.6.2, Xcode 26.6 build 17F113, SDK 26.5, iPhone 15 Pro simulator running iOS 17.5 build 21F79, Node 22.23.2, Homebrew OpenJDK 21.0.12.1. The official iOS 17.5 runtime is now installed and working locally. This does not reproduce CI's Xcode 16.2 / SDK 18.2 toolchain.

The complete terminal log is `/tmp/syntholo-baseline-ios17-f83eb0d.XXXXXX.log`. Retained local XCTest evidence includes:

- `/tmp/syntholo-baseline-ios17-f83eb0d-unit.xcresult`
- `/tmp/syntholo-baseline-ios17-f83eb0d-functional-shell.xcresult`
- `/tmp/syntholo-baseline-ios17-f83eb0d-functional-curriculum.xcresult`
- `/tmp/syntholo-baseline-ios17-f83eb0d-functional-onboarding.xcresult`
- `/tmp/syntholo-baseline-ios17-f83eb0d-evidence.MnGRLE/`

These are local temporary artifacts, not portable CI attachments. The commands and source revision above are the reproduction instructions.

## Failed-run evidence retention

Commit `4cb38541353f44b566d76668236f8066938489e1` corrects the canonical runner's unconditional result-directory cleanup. Once results are allocated and the EXIT trap executes, failed or interrupted runs retain their XCTest results directory and report its path when stderr is writable. SIGKILL cannot execute an EXIT handler. Only a successful run that reaches the final Rules gate is cleaned up. The handler preserves the original exit status and leaves default signal termination in place.

The new shell regression executes the real runner with external build/tooling doubles. Eight behavior cases passed: unit failure, final Rules failure, success cleanup, HUP, INT, TERM, closed-stderr failure reporting, and asynchronous TERM while a real external child is running. The original cleanup was observed deleting failed evidence before the correction. Existing retry and result-assertion suites, syntax checks, and independent review passed. Synthetic cancellation cases do not cancel the canonical run; their expected diagnostics are captured in their fixture logs.

## CI credentials and required checks

The independently reviewed follow-up `90520687afdbf114e3dae8d7680993509be635bf` adds explicit `contents: read` permissions and `persist-credentials: false` to both jobs while retaining `fetch-depth: 0`. Its contract test failed before the workflow change and passed afterward; sixteen unsafe workflow mutations were rejected. This commit is included in the baseline branch. The main agent independently reran its contract and syntax checks successfully, and it passed again in the final canonical invocation.

The repository's default token permissions were already read-only when inspected; this change makes the policy explicit and prevents checkout credentials from remaining available to subsequent build and test steps.

Remote `main` branch protection is now configured and independently read back through GitHub's API:

- Require `test` and `test-ios-17` from the GitHub Actions app (ID 15368).
- Require an up-to-date branch and apply the checks to administrators.
- Deny force pushes and branch deletion.
- Keep merge commits allowed.

`gh pr checks 3 --required` now recognizes both canonical jobs. At the pre-push checkpoint, [run 34006283762](https://github.com/mxima561/syntholo-ios/actions/runs/34006283762) was failed before execution: both jobs had zero steps and reported that account payments failed or the spending limit needed to increase. Required checks must pass on the final PR head; the local pass does not replace them. No CI pass or merge is claimed.

## Remaining delivery and product work

1. Deliver the reviewed accessibility, CI credential, evidence-retention corrections, and this checkpoint through PR #3. Local verification at `a2b2867` is complete; preserve its exact evidence scope.
2. Restore GitHub Actions billing, run both canonical CI jobs, and finish automated review on the final PR commit. Merge PR #3 with a merge commit only after every check is green.
3. Preserve PR #4 by merging the landed baseline into its branch. Update unit count to 233, functional onboarding partition to 17, functional total to 29, and onboarding accessibility count to 12 in both the retry helper argument and final result assertion. Update the matching `OnboardingUITests:17` assertion in `tests/scripts/test_ci_configuration.sh` as well as `scripts/test.sh`; the former was added after PR #4 branched. Preserve the current retry partitions, failure-retention handler, completion flag, and regression invocation when resolving `test.sh`. The new retention fixture derives the caller's count and needs no separate count update. Verify the recovery-only diff and rerun its checks before merging.
4. Resolve the launch-specialization choice, approved staging project/principals, and original-content authorization in the Phase 2 content-load gate. Firebase CLI currently fails `projects:list --json` because it is not authenticated. The checked-in environment list remains emulator-only. Live publisher/rollback connection support is also unfinished; access alone will not complete staging implementation.
5. Approve the daily-goal contract and complete live identity and physical accessibility verification. After approved Phase 2 fixture evidence, continue the lesson engine and subsequent phases in the master plan's dependency order.

The current automated synthetic accessibility coverage is not physical VoiceOver, Switch Control, live-provider, approved-curriculum, or App Store certification.

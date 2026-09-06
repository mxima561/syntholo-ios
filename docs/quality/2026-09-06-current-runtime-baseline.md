# Current-runtime baseline and launch continuation

**Date:** September 6, 2026 (America/New_York)

**Authority:** [Launch completion master plan](../superpowers/plans/2026-08-30-syntholo-ios-launch-completion-master-plan.md), Stage 0; [Product Bible](../superpowers/specs/2026-08-25-syntholo-product-bible.md).

**Outcome:** The full current-runtime canonical invocation passed 487/487 with exit 0, zero failed/skipped/cancelled tests, and no actual runtime retry. Required remote CI, Phase 1/2 exits, and all four launch gates remain open.

## Exact source and runtime

The command started at clean baseline revision `4aea165f4af2747e060a0fc9db5431f2746ccaca` in PR #3. The difference from the September 5 minimum-runtime-tested application/runner revision `a2b2867adf6d1d0dc3576b2a260afcf145117137` is documentation only. Application, tests, runner, and configuration are unchanged during this invocation; this checkpoint document was drafted while it ran.

- macOS 26.6.2, build 25G83.
- Xcode 26.6, build 17F113; SDK 26.5.
- Dedicated Syntholo Canonical iPhone 17 Pro simulator, iOS 26.5 build 23F77, UDID `DE03DC0C-47B0-44C1-AB3D-B0D35CE5213D`.
- Node 22.23.2 and Homebrew OpenJDK 21.0.12.1.

The Build iOS Apps workflow first built and launched this revision through XcodeBuildMCP and captured the rendered welcome screen. That smoke check is separate from the complete repository gate below; it does not prove live authentication or lesson execution.

```bash
env -u SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT \
  SYNTHOLO_DESTINATION='platform=iOS Simulator,id=DE03DC0C-47B0-44C1-AB3D-B0D35CE5213D' \
  ./scripts/test.sh
```

The actual invocation used `set -o pipefail` and `tee` to retain `/tmp/syntholo-baseline-ios26-4aea165-canonical.log` without masking the runner's exit status. The canonical runner includes backend/content validation, test-harness checks, environment checks, Swift unit/UI/accessibility suites, and final Firestore Rules; a simulator-only test command is not a substitute.

## Canonical result

One uninterrupted invocation completed on September 6 at approximately 00:23 local time. The actual terminal exit was 0, including the final Rules gate and emulator shutdown.

| Counted suite | Result |
| --- | --- |
| Curriculum content | 73 passed |
| Operator identity | 32 passed |
| Publication/rollback | 38 passed |
| Swift unit | 232 passed |
| Functional UI | 28 passed: shell 2, curriculum 10, onboarding 16 |
| AppShell accessibility | 28 passed |
| Curriculum accessibility | 14 passed |
| Onboarding accessibility | 11 passed |
| Firestore Rules | 31 passed |
| **Total** | **487 passed; zero failed, skipped, or cancelled** |

A passive collector copied all 47 completed XCTest bundles before successful-run cleanup to `/tmp/syntholo-baseline-ios26-4aea165-evidence/`. Independent reads of every saved summary confirmed 313 XCTest passes, zero failed/skipped/expected-failure tests, and the same iPhone 17 Pro / iOS 26.5 device throughout. The remaining 174 counted passes are the content, identity, publication, and Rules suites. These local temporary artifacts are not uploaded CI evidence; the source and command above provide reproduction instructions.

No canonical UI test retried or opted out of accessibility. Earlier `testSyntheticAudit` timeout messages belong to the deliberate retry-harness regressions, not runtime failures. Xcode's debugger-version warnings did not skip or fail tests. The maximum-size preview audit completed normally in approximately 179 seconds.

The complete Git-history, worktree, generated-project, and built-app secret scan also passed with Gitleaks 8.30.1, including extracted binary/plist strings:

```bash
./scripts/scan_secrets.sh --history --worktree \
  --generated Syntholo.xcodeproj \
  --bundle DerivedData/Build/Products/Debug-iphonesimulator/Syntholo.app
```

The completed minimum-runtime companion is recorded separately in [September 5 verification](2026-09-05-baseline-ci-verification.md): 487/487 on iPhone 15 Pro / iOS 17.5 at the same executable source. That historical local result does not replace the required GitHub Actions Xcode 16.2 lane.

## Delivery blocker

At this report's pre-push checkpoint, PR #3 is open at `4aea165`. GitHub [run 34009933107](https://github.com/mxima561/syntholo-ios/actions/runs/34009933107) has two failed required jobs, `test` and `test-ios-17`, with zero executed steps. The API annotation states that the jobs could not start because account payments failed or the spending limit must increase. This is a pre-execution billing blocker, not a failing application test. Checks must be refreshed on the final PR head after this documentation commit.

The owner must resolve billing before required CI can run. Do not bypass the protected checks, treat local tests as remote CI, or merge PR #4 before PR #3 lands. At the same checkpoint, the CodeRabbit success status is not evidence of a fresh review of the latest accessibility fixes: automatic reviews are paused; independent code reviews are recorded in the September 5 checkpoint.

Read-only inspection of the existing review comments found no new demonstrated P0/P1 defect. The alleged missing analytics initializer is supplied in the unit-test target, and persistence recovery UI is rendered centrally by `RootView`; neither is the separate failed-sign-out bug preserved in PR #4. Two nonblocking operator-tool issues remain tracked: [fractional/exponent JSON errors use a generic diagnostic](https://github.com/mxima561/syntholo-ios/pull/3#discussion_r3910682103), and [standalone validation can throw when the synthetic fixture directory is absent](https://github.com/mxima561/syntholo-ios/pull/3#discussion_r3910682099). Invalid publication input still fails closed. This inventory is not a new CodeRabbit review or a claim that all comments are resolved.

## Ordered continuation

1. Local current/minimum-runtime verification is complete at the executable source recorded above. Restore GitHub Actions billing, obtain both required green checks on the final PR #3 head, and complete final automated review. Merge PR #3 with a merge commit only after all checks pass.
2. Merge the landed baseline into the existing PR #4 recovery branch. Preserve the partitioned runner, timeout-only retry policy, diagnostic attachments, failure retention, credential controls, and both onboarding layout fixes. Update unit count to 233, functional onboarding partition and CI-contract assertion to 17, every functional-total guard/diagnostic to 29, and both onboarding accessibility counts to 12. The resulting canonical total is 490. Verify the integrated revision on both runtimes and required CI; historical PR #4 results are not integration proof.
3. Obtain the still-open approval of the frozen Phase 2 contract from Product, curriculum, iOS, backend, privacy, and accessibility owners. Separately resolve the mandatory [content-load gate](../superpowers/plans/2026-08-30-syntholo-curriculum-platform.md#content-load-gate--mandatory-stop): dated specialization acceptance in the Bible, matching tracked decision record, approved staging project ID/number and keyless publisher principals, and Product/curriculum authorization for original Foundations authoring and staging load. The gate remains 0/4; the environment list is emulator-only. Passing those four checks does not replace the six-owner contract approval.
4. After those approvals and inputs, implement the live staging publisher/rollback connection, author and review the original fixture, and prove immutable publication, unauthorized-write denial, exact device load, cache/relaunch, and rollback. Credentials alone do not finish this work. Record Phase 2 exit evidence before starting the Phase 3 player/attempt plan.
5. In parallel only after its separate Product contract is complete, implement [daily goal and learning settings](../superpowers/plans/2026-08-30-syntholo-daily-goal-settings.md). Complete live identity and physical-device accessibility verification with approved Firebase/Apple/provider access. Do not infer daily-goal values, copy, migration, or allowance semantics.
6. Continue the master plan: lesson engine and durable attempts → AI scoring/coaching → progression → verified StoreKit entitlements → bounded social → settings/data rights/content/operations → signed release certification. No launch gate is passed by synthetic baseline tests.

The app currently offers onboarding and a read-only curriculum preview, not the launch-ready learn/answer/feedback/progress loop. This checkpoint closes a verification gap only; it does not declare the product finished.

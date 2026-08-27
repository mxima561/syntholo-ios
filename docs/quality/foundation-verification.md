# iOS Foundation Verification

Date: 2026-08-26

Status: verified with concerns. The canonical suite passes locally and on a clean GitHub-hosted runner, including all 28 XCTest accessibility audits. An additive iOS 17.5 CI job is configured but cannot be claimed as passed until this unpushed commit runs in GitHub Actions. The manual largest-Dynamic-Type plus Reduce-Motion review is also not claimed.

## Environment

- Local Xcode: 26.6 (build 17F113)
- Clean runner: GitHub Actions `macos-26`, Xcode 26.6 (build 17F113)
- XcodeGen: 2.46.0 locally
- Local host recorded by the result bundles: macOS 26.6.1
- Local test device: iPhone 17 Pro simulator, `69F87C12-6D54-4B06-85DC-B40F68282677`
- Local and clean-runner runtime: iOS 26.5 (build 23F77)
- Deployment target: iOS 17.0
- Device family: iPhone only (`TARGETED_DEVICE_FAMILY = 1`; generated `UIDeviceFamily = [1]`)
- Compatibility job: GitHub Actions `macos-14`, Xcode 16.2 (build 16C5032a), iPhone 15 Pro, iOS 17.5. This supported runner image includes that Xcode/runtime combination; the job has not run because this task is not authorized to push.

Environment commands:

```sh
xcodebuild -version
xcodegen --version
xcrun simctl list runtimes
xcrun simctl list devices
xcodebuild -project Syntholo.xcodeproj -scheme Syntholo -sdk iphonesimulator -showBuildSettings
/usr/libexec/PlistBuddy -c 'Print :UIDeviceFamily' DerivedData/Build/Products/Debug-iphonesimulator/Syntholo.app/Info.plist
/usr/libexec/PlistBuddy -c 'Print :CFBundleIcons' DerivedData/Build/Products/Debug-iphonesimulator/Syntholo.app/Info.plist
```

The settings check returned `IPHONEOS_DEPLOYMENT_TARGET = 17.0` and `TARGETED_DEVICE_FAMILY = 1`. The generated product has `UIDeviceFamily = [1]`. `CFBundleIcons` does not exist, confirming that the empty AppIcon set remains unselected.

## Reproducible suite and generated drift

The canonical `scripts/test.sh` bootstraps the generated project, runs 7 unit tests and 2 shell UI tests, then runs all 28 methods in `AccessibilityAuditUITests` sequentially in one dedicated `test-without-building` process under a 600-second watchdog. The script accepts `SYNTHOLO_DESTINATION` so CI can exercise a precise compatibility runtime; its default remains the iPhone 17 Pro current-runtime destination. `SYNTHOLO_SKIP_ACCESSIBILITY_AUDIT=1` is an explicit, announced diagnostic-only path that exits successfully after the 9 baseline tests; it is not an acceptance path, and the default/CI path continues to enforce the audit gate.

Required two-pass sequence:

```sh
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
```

| Pass | Baseline result | Accessibility result | Generated project SHA-256 |
| --- | --- | --- | --- |
| 1 | 9 passed (7 unit, 2 shell UI), 0 failed/skipped | 28 passed, 0 failed/skipped | `5342fbc9bbce65146ce1179c15c543fd3dd6c8a4fa3a630b8ae00cd48be553ba` |
| 2 | 9 passed (7 unit, 2 shell UI), 0 failed/skipped | 28 passed, 0 failed/skipped | `5342fbc9bbce65146ce1179c15c543fd3dd6c8a4fa3a630b8ae00cd48be553ba` |

Fresh result bundles:

- Pass 1 baseline: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_23-16-27--0400.xcresult`
- Pass 1 accessibility: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_23-16-51--0400.xcresult`
- Pass 2 baseline: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_23-20-28--0400.xcresult`
- Pass 2 accessibility: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_23-20-51--0400.xcresult`

`xcresulttool get test-results summary` independently reported the exact pass counts above. Both post-pass status checks showed only the intentional Task 10 workflow/script edits; no generated or unexpected path appeared. The generated project hash was identical. `git check-ignore -v Syntholo.xcodeproj DerivedData` confirms both generated paths remain ignored.

The shell UI checks prove that Learn is initially selected, all four tab labels exist, and Learn, Practice, Social, and Profile each open their navigation destination.

## Accessibility evidence

`SyntholoUITests/AppShellUITests.swift` defines 28 iOS 17 XCTest audit methods in `AccessibilityAuditUITests`: contrast, element detection, hit region, sufficient element description, Dynamic Type, clipped text, and traits for each of Learn, Practice, Social, and Profile. The canonical script selects this class, disables parallel testing, and therefore runs one `performAccessibilityAudit` call at a time.

The original corrected-selector runs did not stall: they completed and identified a real contrast defect in secondary text (`Contrast nearly passed`). Changing `SyntholoColor.secondaryInk` from SwiftUI `.secondary` to UIKit `.label` preserved semantic system-color behavior while satisfying the audit. Evidence retained in local result bundles:

- `11-17-36` and `11-18-40`: focused `AccessibilityAuditUITests/testLearnContrastAudit` failed with the contrast finding.
- `11-19-49`: the same focused audit passed after the token correction.
- `11-20-11` and `11-24-10`: the complete 28-audit suite passed.
- The two fresh complete-suite bundles listed above each passed 28 of 28 audits.

Clean-runner evidence: GitHub Actions run [33006796942](https://github.com/mxima561/syntholo-ios/actions/runs/33006796942), at commit `fb6bfc066ebae1695d987a4392435f823a959cda`, passed on `macos-26` / Xcode 26.6 in 15 minutes 8 seconds. Its canonical test step passed the 7 unit tests, 2 shell UI tests, and the whole 28-method `AccessibilityAuditUITests` class. The `-quiet` audit invocation suppresses per-method log lines, so the exact 28 count is corroborated by the selected source class and the local xcresult summaries.

A manual largest-Dynamic-Type plus Reduce-Motion review is not claimed. Local command-line simulator tooling did not expose a reproducible Reduce Motion control, and Accessibility Inspector GUI automation was unavailable. Automated Dynamic Type, clipping, hit-region, label, trait, element-detection, and contrast audits do pass.

## iOS 17 compatibility gate

The local machine has no iOS 17 simulator runtime. The existing current-iOS job remains unchanged in coverage. A separate `test-ios-17` workflow job now runs the complete canonical script using the supported GitHub `macos-14` image, `/Applications/Xcode_16.2.app`, and `platform=iOS Simulator,name=iPhone 15 Pro,OS=17.5`.

This is a reproducible path to an actual iOS 17 simulator test without weakening current-iOS coverage. It remains an external evidence dependency: this task may not push, so the job can run only after the commit is pushed to GitHub. GitHub's official [`macos-14` inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-14-Readme.md) documents the selected Xcode/runtime/device combination and schedules the image to become unsupported on 2026-11-02; the job should later move to a supported runner/image that still provides or installs an iOS 17 runtime. The existing job's current toolchain is recorded in the official [`macos-26` inventory](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md).

## Scans and dependency boundary

Exact required scan:

```sh
rg -n 'TODO|TBD|FIXME|YOUR_API_KEY|sk-[A-Za-z0-9]' Syntholo Config scripts project.yml
```

Result: exit 1 with no output, the expected no-match result.

Additional boundary inspection found no networking, authentication, purchase, credential, or external production dependency. Imports are limited to SwiftUI, Observation, Foundation, and XCTest. The AppIcon directory contains only `Contents.json`; no temporary artwork was added.

## Warning disposition

### Resolved product warnings and defects

- Interface orientations: XcodeGen target defaults had generated `TARGETED_DEVICE_FAMILY = "1,2"`. Setting it to `1` on the app and test targets makes the product consistently iPhone-only and removes the warning without changing supported iPhone behavior.
- Accessibility contrast: the XCTest audit found the low-margin secondary-text contrast described above. The semantic `.label` token correction is covered by focused and complete audit passes.

### Remaining toolchain/runtime warnings

- App Intents metadata extraction: Xcode 26.6 emits `Metadata extraction skipped. No AppIntents.framework dependency found.` The foundation has no App Intents or framework dependency. No unrelated framework was added and no global warning suppression was introduced.
- LLDB metadata: UI runs emit `DebuggerLLDB.DebuggerVersionStore.StoreError` and `no debugger version`; tests still execute and pass locally and on the clean runner.
- Simulator accessibility loader: iOS 26.5 can log duplicate `UIAccessibilityLoaderWebShared` classes from managed runtime bundles. The complete audit suite nevertheless passes.

These are ledgered toolchain/runtime concerns, not observed product failures.

## PRD traceability

This is foundation-level evidence, not a claim that later MVP requirements are implemented.

| PRD section | Foundation evidence | Disposition |
| --- | --- | --- |
| 3 — Target audience / launch constraints | iPhone-only generated product; English localization catalog; localization-ready SwiftUI shell | Covered at foundation scope |
| 4 — Product principles | Native, restrained shell; no credential, network, auth, or purchase implementation; automated accessibility defects are treated as blocking | Covered at foundation scope |
| 11 — Information architecture | Learn, Practice, Social, and Profile boundaries exist; UI automation proves all four destinations are reachable | Covered at shell scope |
| 15 — Visual and interaction design | Semantic system colors and design tokens; native tab/navigation behavior; minimum control-height test | Covered at foundation scope |
| 16 — Technical architecture | Native SwiftUI app, Observation router, typed routes, feature directory boundaries, no premature service SDKs | Covered at foundation scope |
| 22 — Accessibility | Minimum target-size unit test plus 28 passing XCTest audits across all four tabs; manual Reduce Motion review not claimed | Automated foundation gate passed; manual evidence open |
| 28 — Acceptance criteria | No later P0 product flow is claimed; privacy/accessibility release criteria remain traceable | Covered only at foundation scope |
| 29 — Testing strategy | Reproducible unit/UI suite, shell navigation automation, bounded comprehensive accessibility gate, current-iOS clean-runner pass, additive iOS 17 compatibility job | Covered; first iOS 17 job run pending push |

## Exit assessment

The generated SwiftUI foundation is reproducible; local and clean-runner canonical suites pass; all 28 automated accessibility audits pass; navigation works across the four-tab shell; product scope remains local and credential-free; the iPhone-only orientation warning and the discovered contrast defect are fixed; and generated artifacts remain ignored. Task 10 is no longer blocked by accessibility. Remaining concerns are the unclaimed manual largest-text/Reduce-Motion review, the unexecuted additive iOS 17 compatibility job, and the visible but unsuppressed Xcode App Intents/toolchain warnings.

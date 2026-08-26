# iOS Foundation Verification

Date: 2026-08-26

Status: done with concerns; the normal foundation suite, configuration, scans, and generation checks pass, but the reproducible XCTest accessibility audit is blocked by the local Xcode/CoreSimulator harness.

## Environment

- Xcode: 26.6 (build 17F113)
- XcodeGen: 2.46.0
- Host recorded by the result bundle: macOS 26.6.1
- Test device: iPhone 17 Pro simulator, `69F87C12-6D54-4B06-85DC-B40F68282677`
- Runtime: iOS 26.5 (26.5, build 23F77)
- Also installed: iOS 26.4 (26.4, build 23E244)
- Deployment target: iOS 17.0
- Device family: iPhone only (`TARGETED_DEVICE_FAMILY = 1`; generated `UIDeviceFamily = [1]`)
- An iOS 17 simulator runtime is not installed locally. The current-runtime launch passed, and the build targets `arm64-apple-ios17.0-simulator`; an actual iOS 17 runtime launch remains a release-matrix check.

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

The audit class is compiled but excluded from the normal script because invoking `performAccessibilityAudit` stalls the local test harness as documented below.

```sh
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
./scripts/test.sh
git status --short
shasum -a 256 Syntholo.xcodeproj/project.pbxproj
```

Results:

| Pass | Result | Unit | Shell UI | Generated project SHA-256 |
| --- | --- | ---: | ---: | --- |
| 1 | Passed | 7 | 2 | `5342fbc9bbce65146ce1179c15c543fd3dd6c8a4fa3a630b8ae00cd48be553ba` |
| 2 | Passed | 7 | 2 | `5342fbc9bbce65146ce1179c15c543fd3dd6c8a4fa3a630b8ae00cd48be553ba` |

Result bundles:

- Pass 1: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_00-54-59--0400.xcresult` — 9 passed, 0 failed, 0 skipped.
- Pass 2: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_00-55-37--0400.xcresult` — 9 passed, 0 failed, 0 skipped.

Both status checks reported only the intentional Task 10 edits then in progress; no generated or unexpected path appeared. The generated project hash was identical. `git check-ignore -v Syntholo.xcodeproj DerivedData` confirms both generated paths remain ignored.

The UI checks prove that Learn is initially selected, all four tab labels exist, and Learn, Practice, Social, and Profile each open their navigation destination on the current simulator.

## Accessibility evidence and blocker

`SyntholoUITests/AppShellUITests.swift` contains an iOS 17 XCTest audit matrix for every primary tab and every Swift-exposed audit category: contrast, element detection, hit region, sufficient element description, Dynamic Type, clipped text, and traits. Each category/tab pair is a separate method so the harness is not asked to run a combined `.all` audit.

Final bounded reproduction after shutting down the simulator and restarting only the identified CoreSimulator service stack:

```sh
xcodebuild -quiet test-without-building \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination 'platform=iOS Simulator,id=69F87C12-6D54-4B06-85DC-B40F68282677' \
  -derivedDataPath DerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoUITests/AppShellUITests/testLaunchesOnLearnAndShowsEveryPrimaryTab

xcodebuild -quiet test-without-building \
  -project Syntholo.xcodeproj \
  -scheme Syntholo \
  -destination 'platform=iOS Simulator,id=69F87C12-6D54-4B06-85DC-B40F68282677' \
  -derivedDataPath DerivedData \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:SyntholoUITests/AppShellUITests/testLearnContrastAudit
```

The control UI test passed 1/1 in 11.767 seconds. The immediately following single-tab/single-category audit stalled until it was interrupted at 47.539 seconds. Xcode reported `waiting for workers to materialize` and `Waiting for -runningDidFinish call`; the result bundle records one canceled test and no accessibility finding:

- Control: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_00-51-57--0400.xcresult`
- Audit: `DerivedData/Logs/Test/Test-Syntholo-2026.08.26_00-52-17--0400.xcresult`

Earlier exploratory `.all`, multi-category, and isolated-category attempts also became nonresponsive or were killed by the harness. The behavior reproduced on the installed 26.5 and 26.4 runtimes. Because the audit did not complete, no automated accessibility pass is claimed and this remains a foundation exit blocker. The audit class is excluded from `scripts/test.sh` so it does not make the otherwise passing normal suite hang.

A manual largest-Dynamic-Type plus Reduce Motion review is also not claimed. Local `simctl ui ... --help` can set the content-size category but exposes no Reduce Motion control, and Accessibility Inspector GUI automation was not available in this run. The tab-label, scrolling, and clipping review must be completed with appropriate simulator UI tooling after the XCTest harness issue is resolved.

## Scans and dependency boundary

Exact required scan:

```sh
rg -n 'TODO|TBD|FIXME|YOUR_API_KEY|sk-[A-Za-z0-9]' Syntholo Config scripts project.yml
```

Result: exit 1 with no output, which is the expected no-match result.

Additional boundary inspection searched the same implementation scope for networking, authentication, purchases, SDKs, credentials, URLs, and package/framework declarations. It found no match. Imports are limited to SwiftUI, Observation, Foundation, and XCTest. No networking, authentication, purchase, credential, or external production dependency is present.

The AppIcon directory contains only `Contents.json`; no temporary artwork was added.

## Warning disposition

### Resolved product warning

An earlier build warned that all interface orientations must be supported unless full screen is required. The cause was concrete: XcodeGen's target defaults generated `TARGETED_DEVICE_FAMILY = "1,2"` despite the project-level iPhone setting. Setting `TARGETED_DEVICE_FAMILY = "1"` on the app and both test targets makes the generated product iPhone-only and removes the orientation warning without changing supported iPhone behavior. Both final suite logs are free of the orientation warning.

### Unresolved toolchain/runtime warnings

- App Intents metadata extraction: Xcode 26.6 emits `Metadata extraction skipped. No AppIntents.framework dependency found.` There are no App Intents or framework dependency in the foundation. Xcode's local specification exposes only a warning filter, not a documented safe metadata-skip build setting. The warning was not globally hidden and AppIntents.framework was not added merely to silence it.
- LLDB metadata: UI runs emit `DebuggerLLDB.DebuggerVersionStore.StoreError` and `no debugger version`. Tests still execute and pass; this is local debugger metadata, not app behavior.
- Simulator accessibility loader: iOS 26.5 logs duplicate `UIAccessibilityLoaderWebShared` classes in the runtime's WebCore and WebKit accessibility bundles and warns of possible crashes. This is inside the managed simulator runtime. It is a plausible environmental contributor to the audit stall, but that relationship is not proven.
- The build-settings inspection command warned about multiple matching destinations because it intentionally omitted a destination; the two verification suites used the named iPhone 17 Pro and resolved to the recorded 26.5 device.

No broad compiler-warning suppression was added.

## PRD traceability

This is foundation-level evidence, not a claim that later MVP requirements are implemented.

| PRD section | Foundation evidence | Disposition |
| --- | --- | --- |
| 3 — Target audience / launch constraints | iPhone-only generated product; English localization catalog; localization-ready SwiftUI shell | Covered at foundation scope |
| 4 — Product principles | Native, restrained shell; no dark-pattern, credential, network, auth, or purchase implementation; accessibility gate is treated as blocking rather than waived | Covered at foundation scope, accessibility blocker open |
| 11 — Information architecture | Learn, Practice, Social, and Profile boundaries exist; UI automation proves all four destinations are reachable | Covered at shell scope |
| 15 — Visual and interaction design | Warm neutral, ink, academic-blue and supporting token primitives; native tab/navigation behavior; minimum control-height test | Covered at foundation scope |
| 16 — Technical architecture | Native SwiftUI app, Observation router, typed routes, and feature directory boundaries; no premature service SDKs | Covered at foundation scope |
| 22 — Accessibility | Minimum target-size unit test plus comprehensive iOS 17 audit matrix | Not verified: automated audit harness and manual combined review remain blocked |
| 28 — Acceptance criteria | No later P0 product flow is claimed; privacy/accessibility release criterion is explicitly held open | Traceable, not yet satisfied by foundation |
| 29 — Testing strategy | Reproducible unit/UI script, two clean runs, shell UI automation, and accessibility audit code | Automated normal suite covered; accessibility/manual device review open |

## Exit assessment

The generated SwiftUI foundation is reproducible, current-runtime launch/navigation passes twice, product scope remains local and credential-free, the iPhone-only orientation warning is fixed, and generated artifacts remain ignored. The foundation is **done with concerns**, not fully cleared: the automated accessibility audit and manual largest-text/Reduce-Motion review are unverified, an actual iOS 17 runtime launch was unavailable, and the Xcode App Intents tooling warning remains visible rather than suppressed.

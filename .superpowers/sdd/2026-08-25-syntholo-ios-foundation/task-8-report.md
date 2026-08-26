# Task 8 Report: UI Smoke Tests for Launch and Navigation

## Changes

- Added `SyntholoUITests/AppShellUITests.swift` with native XCTest UI smoke tests for the Learn launch state and all four primary tabs.
- Preserved the exact native accessibility labels/titles: `Learn`, `Practice`, `Social`, and `Profile`.
- Restored `SyntholoUITests` to the `Syntholo` scheme's `testTargets` in `project.yml` and regenerated the ignored `Syntholo.xcodeproj`.
- Kept the `--ui-testing` launch argument. No production source changed.

## Commands and Results

1. `xcodegen generate`
   - Result: generated `Syntholo.xcodeproj` successfully.

2. `xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:SyntholoUITests/AppShellUITests`
   - First attempted within the filesystem sandbox; it could not connect to CoreSimulatorService, so no tests executed.
   - Re-run with simulator access: `** TEST SUCCEEDED **`.
   - Executed 2 UI tests; passed 2; failures 0.

3. `xcodebuild test -project Syntholo.xcodeproj -scheme Syntholo -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`
   - Result: `** TEST SUCCEEDED **`.
   - Unit bundle: executed 7; passed 7; failures 0.
   - UI bundle: executed 2; passed 2; failures 0.
   - Full scheme: executed 9; passed 9; failures 0.

4. `git diff --check`
   - Result: no whitespace errors.

## Self-review

- The tests use the app's native tab-button labels and navigation-bar titles rather than test-only identifiers.
- The launch test asserts every primary tab and the initial Learn destination; the navigation test visits all tabs and returns to Learn.
- Each navigation assertion waits up to two seconds, limiting timing sensitivity while preserving failure visibility.
- The UI-test target is in the generated scheme after `xcodegen generate`; the source-of-truth scheme change is committed in `project.yml`.
- No networking, authentication, purchases, credentials, or production changes were introduced.

## Concerns and Flakiness

- No functional flakiness observed: the focused UI run and the full scheme run both passed.
- Xcode/CoreSimulator emitted environment warnings about `DebuggerLLDB.DebuggerVersionStore` and duplicate `UIAccessibilityLoaderWebShared` runtime classes. They did not affect execution or test results and are not introduced by this change.
- The generated `Syntholo.xcodeproj` is intentionally ignored; it was regenerated locally and its shared scheme includes `SyntholoUITests`.

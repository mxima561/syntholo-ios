# Task 9 Report: Reproducible Test Script and CI

## Changes

- Added `scripts/test.sh`, an executable strict-mode script that generates the project before running the full `Syntholo` scheme on `iPhone 17 Pro` with code signing disabled and `DerivedData` in the repository.
- Added `.github/workflows/ios.yml`, which runs on `macos-26`, installs dependencies with `brew bundle`, selects `/Applications/Xcode_26.6.app`, and invokes the test script for pull requests and pushes to `main`.
- No product source, `project.yml`, networking, authentication, purchase, or credential changes were made.

## Commands and Results

1. `bash -n scripts/test.sh`
   - Result: exit 0; shell syntax valid.

2. `ruby -e "require 'yaml'; YAML.load_file('.github/workflows/ios.yml'); puts 'YAML syntax OK'"`
   - Result: `YAML syntax OK`.

3. `stat -f '%Sp %N' scripts/test.sh`
   - Result: `-rwxr-xr-x scripts/test.sh`; the executable mode bit is present.

4. `zsh -o pipefail -c './scripts/test.sh 2>&1 | tee /private/tmp/syntholo-task9-test.log'`
   - Result: exit 0 and `** TEST SUCCEEDED **`.
   - Unit bundle (`SyntholoTests.xctest`): executed 7, passed 7, failures 0.
   - UI bundle (`SyntholoUITests.xctest`): executed 2, passed 2, failures 0.
   - Full scheme: executed 9, passed 9, failures 0.

5. `git diff --check`
   - Result: no whitespace errors.

## Self-review

- `scripts/test.sh` uses `#!/usr/bin/env bash` and `set -euo pipefail`, runs `./scripts/bootstrap.sh` first, and targets the full `Syntholo` scheme on `iPhone 17 Pro` with `CODE_SIGNING_ALLOWED=NO` and `-derivedDataPath DerivedData`.
- The workflow is pinned to `macos-26` and `/Applications/Xcode_26.6.app`, uses `brew bundle`, and runs the root-level script for both required GitHub events.
- Only the requested script, workflow, and task report are included; ignored generated project and DerivedData outputs remain untracked.

## Concerns

- The initial sandboxed attempt could not connect to `CoreSimulatorService`, so no tests executed there. The required full run with local simulator access passed.
- Xcode emitted environment warnings about `DebuggerLLDB.DebuggerVersionStore` and duplicate `UIAccessibilityLoaderWebShared` runtime classes. They did not affect the passing test result and were not introduced by this change.

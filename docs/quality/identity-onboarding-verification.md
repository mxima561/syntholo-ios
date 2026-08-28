# Identity and onboarding verification

Verified on 2026-08-27 against Phase 1 base commit
`9d0d40873869648ffc6237d431702ce3ceaa8447`.

## Release status

The local automated identity/onboarding exit gate is green on the verified
toolchain below. The repository has
deterministic coverage for every required Phase 1 journey, every distinct
onboarding and recovery layout, both build configurations, and Firestore
Rules. Live Firebase console credentials are intentionally absent, so live
Apple, Google, and email authentication remain deployment checks rather than
repository test evidence.

Remote CI is pending until this branch is pushed. Neither configured GitHub
Actions job has run for this unpushed commit, so this document does not claim a
current-iOS or iOS 17.5 remote pass.

Local release readiness remains blocked on one manual accessibility check:
spoken VoiceOver focus order on physical hardware. The pending remote CI jobs
must also pass after the branch is pushed. The available iOS Simulator and Mac
accessibility tooling exposed the app's ordered accessibility tree, but did not
provide a working simulated VoiceOver control, observable VoiceOver focus, or
captured speech. This limitation is not recorded as a pass. The exact release
checklist appears below.

## Verified toolchain

| Component | Local verification version | CI pin or target |
| --- | --- | --- |
| macOS | 26.6.1 (25G76) | `macos-26` and `macos-14` runners |
| Xcode | 26.6 (17F113) | Xcode 26.6 and Xcode 16.2 |
| Swift | Apple Swift 6.3.3 | Swift 6.0 project setting |
| Simulator | iPhone 17 Pro, iOS 26.5 (23F77) | current iOS and iPhone 15 Pro, iOS 17.5 |
| Firebase iOS SDK | 12.14.0 | Swift Package lock |
| Google Sign-In iOS | 9.2.0 | Swift Package lock |
| Node | 22.22.2 | 22.22.2 |
| npm | 10.9.7 | lockfile install with `npm ci` |
| Firebase CLI | 15.28.1 | local `node_modules/.bin/firebase`, exact assertion |
| Firestore emulator | 1.22.0 | downloaded by the pinned CLI |
| Firebase JavaScript SDK | 12.18.0 | `package-lock.json` |
| Rules Unit Testing | 5.0.2 | `package-lock.json` |
| Java | OpenJDK 21.0.12.1 | Temurin 21.0.12+8.0.LTS |

## Canonical automated gate

Run the complete local gate from the repository root:

```bash
./scripts/test.sh
```

The script regenerates the Xcode project, proves its watchdog behavior, checks
both CI jobs' exact action/toolchain contract, checks the environment
configuration, builds all test targets, and then runs these exact nonzero
selections:

| Selection | Exact result |
| --- | ---: |
| Swift unit tests | 98 passed, 0 failed, 0 skipped |
| Functional UI tests | 16 passed, 0 failed, 0 skipped (14 onboarding, 2 app shell) |
| AppShell accessibility tests | 28 passed, 0 failed, 0 skipped |
| Onboarding accessibility tests | 10 passed, 0 failed, 0 skipped |
| Firestore Rules tests | 20 tests/pass, 0 failed, 0 cancelled, 0 skipped |

Unit and functional UI tests run under independent target filters and produce
separate result bundles. The XCTest parser requires 98 unit passes and 16
functional UI passes exactly, with zero failures or skips. Dedicated harness
regressions prove that 97/98 units, 15/16 UI tests, or a skipped test fails the
gate. The TAP parser independently requires exactly 20 Rules tests and passes
with zero failures, cancellations, or skips; 19/20 and skipped fixtures are
also rejected. A zero-selected or partially selected suite cannot pass.
AppShell and onboarding accessibility tests retain their own sequential result
bundles so a stalled or failed class has a narrow result boundary.

Every long stage runs through a wall-clock watchdog. The watchdog establishes
a new POSIX process group, verifies that the group exists before monitoring,
uses an epoch deadline that remains expired across system sleep, and escalates
`INT`, `TERM`, then `KILL` to the full group. Its regression uses a parent and
child that ignore `INT` and `TERM`, expects timeout status 124, and verifies
that neither process survives. Unit and Rules stages are capped at 300
seconds; configuration, build, functional UI, and AppShell audits at 600
seconds; onboarding audits at 420 seconds.

### Build configuration proof

`scripts/test_environment_configuration.sh` builds device Debug and Release
artifacts and verifies:

- Debug bundles `SYNTHOLO_ENV=development`;
- Release bundles `SYNTHOLO_ENV=production`;
- both use `com.syntholo.ios`, minimum iOS 17.0, and iPhone device family;
- the Release binary contains no UI-test launch marker or UI-test fake symbol.

The Release scan includes the Task 9 storage/authentication fixture markers
and provider continuation implementation.

## Deterministic journey coverage

| Requirement | Evidence |
| --- | --- |
| Under 13 blocked | Restriction is terminal; no provider or account control is reachable. |
| Teen and adult paths | Teen completes through email; adults complete independently through Apple and Google; each taps the handoff action and reaches Learn/AppShell. |
| All three providers | Apple, Google, and email controls are asserted together on the account screen. |
| Authentication cancellation | Apple and Google each wait for a provider-specific post-await cancellation marker before asserting that the account screen remains without an error; email form cancellation returns to the same screen. |
| Profile-save recovery | A first save failure exposes the typed retry route; retry reaches handoff without showing auth controls again. |
| Kill and relaunch | A per-test persisted draft relaunches at the exact path-selection step without resetting. |
| Completed profile restore | A complete restored profile opens Learn directly without replaying onboarding or handoff. |
| No early interruption | Paywall, Social tab/prompt, catalog/browser, notification action, and system alert absence are checked throughout the pre-handoff journey. |
| Recovery separation | Loading, profile checking, profile-check failure, profile saving, and profile-save failure have distinct deterministic routes. |

All 22 explicit `waitForExistence` calls in the onboarding UI suite specify a
2-, 3-, or 5-second timeout. The two fixture operations used to hold visible
loading states also have a finite 120-second task sleep; the test process never
waits for those operations to finish.

## Accessibility automation

Each onboarding audit uses the unchanged category set:

- contrast;
- element detection;
- hit region;
- sufficient element description;
- Dynamic Type;
- clipped text;
- traits.

The ten tests audit welcome, age, goal, experience, recommended path, expanded
Other paths, coach, account, under-13 restriction, email account, profile
saving, profile-save recovery, profile checking, profile-check recovery,
first-lesson handoff, and session loading layouts. The Account checkpoint
asserts that the production native Apple control is present and the generic
provider fixture control is absent. Provider interaction replacement is
enabled only by the explicit provider-fixture argument used in Apple/Google
completion and cancellation journeys. AppShell adds 28 category-specific
audits across Learn, Practice, Social, and Profile.

The Task 9 accessibility RED exposed three real nodes: `Recommended route` and
the first-lesson action could clip at large Dynamic Type, and the system text
toolbar cancellation item was reported as non-scaling. Text now grows
vertically where required. The email modal uses a standard 44-point close icon
with the accessible name `Cancel`, avoiding an audit exception or hidden
control. The post-review focused sweeps passed 16 of 16 functional UI tests and
10 of 10 onboarding accessibility tests.

## Manual accessibility evidence

### Reduce Motion — simulator pass

Using the final installed build on iPhone 17 Pro / iOS 26.5 (23F77), Reduce
Motion was enabled in Settings > Accessibility > Motion. The accessibility
state reported `REDUCE_MOTION=1`. Syntholo launched to Welcome and the
Welcome-to-Age transition completed with content, controls, hit targets, and
reading tree intact. The onboarding source contains no custom animation,
transition, matched-geometry, phase-animation, or keyframe-animation API. The
setting was restored to its original value (`REDUCE_MOTION=0`) after the check.

### VoiceOver — release-blocking physical-device checklist

The Simulator Accessibility settings did not expose VoiceOver. Host
Command-F5 and VoiceOver-next input did not produce observable item focus or
capturable speech in the simulated app. The inspection tree did show the
expected structural order — for example, Welcome exposed orientation, title,
introduction, then Start; Age exposed Back, orientation, title, introduction,
the three age choices, then the privacy note — but a tree is not spoken
VoiceOver verification.

Before release, complete and record this checklist on a physical iPhone for
both the current supported iOS and iOS 17.5:

1. Install the signed release candidate, clear its onboarding state, enable
   VoiceOver, and launch Syntholo.
2. Swipe forward and backward through Welcome, Age, Goal, Experience,
   recommended path (collapsed and expanded), Coach, Account, Email,
   under-13 restriction, loading, both profile recovery routes, and handoff.
3. Confirm visual reading order, concise names, button/selected traits,
   combined choice title and detail, and that decorative icons are skipped.
4. Trigger authentication cancellation and both recovery errors; confirm the
   error or recovery heading is announced once and focus reaches Retry without
   returning to provider controls.
5. Exercise Back, Cancel, Retry, and Start first lesson; confirm focus lands on
   the new screen's heading or first meaningful element and never disappears.
6. Record device model, OS/build, app commit/build, exact pass/failure notes,
   and tester. Any focus-order or announcement defect blocks release.

## Firestore Rules and local tooling

`scripts/test_firebase_rules.sh` refuses a global Firebase CLI. It compares the
exact Firebase CLI version in `package.json`, `package-lock.json`, and the local
binary; requires Node 22 and Java 21 or newer; discovers Java from `JAVA_HOME`,
`/usr/libexec/java_home`, standard Homebrew locations, or `PATH`; and points to
`docs/setup/firebase.md` when Java is missing.

Each run allocates non-default ephemeral Firestore, hub, and logging ports,
generates a temporary emulator config, uses only project `syntholo-local`, and
removes the config on every exit path. It parses the TAP summary and accepts
only exactly 20 tests/pass with zero failures, cancellations, or skips. The
pinned local run meets that contract and confirms the Firestore listener is
closed when `emulators:exec` returns. Local Rules verification requires neither
Firebase authentication nor production credentials.

## CI self-review

`.github/workflows/ios.yml` parses as YAML and retains both jobs:

- `macos-26`, Xcode 26.6, current iOS destination;
- `macos-14`, Xcode 16.2, iPhone 15 Pro / iOS 17.5.

Both job definitions use the Node 24-based `checkout@v5`, `setup-node@v5`, and
`setup-java@v5` actions; install XcodeGen, exact Node 22.22.2, and exact
available Temurin 21.0.12+8.0.LTS; run `npm ci`; assert local Firebase CLI
15.28.1; select the intended Xcode; and run the same `./scripts/test.sh`. The
canonical gate includes a job-scoped static regression that enforces this
contract independently for both jobs.

Remote run 33139333630 failed both jobs during `setup-java` because the prior
exact value `21.0.8+9` was unavailable; neither job reached repository tests.
This replacement commit has not been pushed, so its two remote job results are
pending controller verification. The older iOS 17.5 runtime is not installed
in the local Xcode 26.6 environment.

## Credential, privacy, and dependency review

The required secret-shape scan found only non-secret text:

- documentation and plan references to the filename
  `GoogleService-Info.plist`;
- the `netmask-2.1.1.tgz` lockfile URL, whose `mask-` substring matches the
  deliberately broad `sk-` expression;
- plan prose containing the same broad substring.

No credential-shaped value was found. `git ls-files` returned no Firebase
plist, environment Firebase plist, or `Config/Firebase.local.xcconfig`.
The forbidden analytics parameter scan for `email`, `displayName`,
`birthDate`, `prompt`, and `answer` returned no match in analytics code.

`npm audit` reports 5 moderate, 0 high, and 0 critical findings in transitive
development-only Firebase CLI dependencies (`@opentelemetry/core` and `uuid`
paths). The suggested forced fix downgrades Firebase CLI to 14.23.0 and is not
accepted. These packages are not shipped in the iOS application and should be
rechecked when the pinned CLI updates.

Known non-product warnings are:

- Xcode's `DebuggerVersionStore` / `no debugger version` launch snapshot
  warning in UI tests;
- the device-build destination warning when more than one generic destination
  matches;
- the Simulator duplicate accessibility bundle/class warning observed in
  verbose audit output;
- expected Firestore `PERMISSION_DENIED`, Rules evaluation, unauthenticated
  CLI, and Node `punycode` diagnostics from negative Rules cases/tooling.

The first pre-document combined audit attempt is not gate evidence. The Mac
entered low-power hibernation at 1% battery from 07:32:24 to 21:17:04, and the
old active-time `sleep` watchdog paused with it. Tests resumed normal per-test
progress immediately on wake. Task 9 replaced that implementation with the
wall-clock process-group watchdog described above and verified the two held
loading audits separately in 43 seconds.

## External deployment configuration

No staging/production Firebase plist, Google client ID/reversed scheme, Apple
private key, live Firebase project, or provider-console credential is present.
This is intentional. Before a signed deployment, follow `docs/setup/firebase.md`,
enable Apple, Google, and Email/Password in each Firebase project, install the
ignored environment files, and run live provider smoke tests. Never copy those
credentials into this document, source control, fixtures, logs, or CI output.

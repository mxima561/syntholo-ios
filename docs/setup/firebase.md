# Firebase setup

Firebase console files and provider identifiers are deployment configuration. Do not commit them.

## Register the iOS app

1. Create separate Firebase projects for staging and production. Development uses the local emulator project and needs no console credentials.
2. In each project, register an Apple app with bundle identifier `com.syntholo.ios`.
3. Download `GoogleService-Info.plist`, rename it to match the environment (`staging.firebase.plist` or `production.firebase.plist`), and place it in `Syntholo/Resources/`.
4. Run `./scripts/bootstrap.sh` after adding or changing a plist so XcodeGen includes it in the app resources.

The environment plist files, the original `GoogleService-Info.plist`, and `Config/Firebase.local.xcconfig` are ignored by Git. Staging and production show a setup-safe state when their selected environment has no valid bundled plist.

## Enable authentication providers

In Firebase Console → Authentication → Sign-in method, enable:

- Apple
- Google
- Email/Password

For Apple, add the **Sign in with Apple** capability to the `Syntholo` target and complete the Apple/Firebase key and redirect-domain configuration. Do not place the Apple private key in this repository.

For Google, copy `Config/Firebase.example.xcconfig` to the ignored `Config/Firebase.local.xcconfig`. `Config/Shared.xcconfig` includes that file when present. Set `GOOGLE_CLIENT_ID` to `CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_SCHEME` to `REVERSED_CLIENT_ID` from the environment plist. The app exposes those values as `GIDClientID` and its callback URL scheme. Never commit either deployment value.

Without the local file, checked-in placeholders keep unsigned builds valid. The Google button remains visible, and selecting it returns a setup message instead of starting the SDK with incomplete configuration. Staging and production deployments must replace both placeholders with a matching client ID and reversed scheme.

## Run local emulators

Content and Rules verification require Node 22 and the exact dependencies in `package-lock.json`. Rules verification additionally requires Java 21 or newer. Install Java with a JDK distribution such as Temurin 21 or Homebrew `openjdk@21`. The runner checks `JAVA_HOME`, macOS `/usr/libexec/java_home`, the standard Homebrew locations, and then `java` on `PATH`. Install XcodeGen with `brew bundle`, then install the scanner with `./scripts/install_gitleaks.sh`. The scanner installer downloads the architecture-specific official gitleaks 8.30.1 release and verifies checked-in archive and binary SHA-256 values; the gate rejects a missing, modified, or version-drifted binary.

Restore the pinned local tooling and run the isolated Rules gate:

```bash
brew bundle
./scripts/install_gitleaks.sh
npm ci
./scripts/test_firebase_rules.sh
```

Do not install or use a global Firebase CLI for verification. The script requires the exact `firebase-tools` version from `package.json` and `package-lock.json`, creates a temporary Firebase config with non-default ephemeral Firestore, hub, and logging ports, and cleans up the emulator on success, assertion failure, interruption, or timeout. It parses the final TAP summary and requires exactly 31 tests and 31 passes with zero failures, cancellations, or skips. Local emulator tests do not require Firebase authentication or live credentials.

## Validate curriculum without publishing

The Phase 2 content contract is pure and creates no Firebase client. The only pre-decision fixture is an unmistakably synthetic record under `tests/fixtures/content/`; it validates the schema/graph/digest boundary but is not launch curriculum and cannot satisfy the Product Bible's specialization gate.

```bash
npm ci
npm run content:validate -- tests/fixtures/content/minimal-curriculum-v1.json
npm run test:content
```

The CLI reads strict UTF-8/JSON, rejects duplicate object keys, validates the closed draft schema and graph, derives immutable Firestore shapes and RFC 8785/SHA-256 digests, and reports only safe IDs, counts, and digests. Synthetic source classification survives a file copy through its reserved sentinel. The publisher rejects synthetic sources unless the resolved environment is exactly the local emulator tuple and `FIRESTORE_EMULATOR_HOST` is set; validation alone never authorizes publication.

## Exercise the emulator-only publisher and rollback path

The Phase 2 operator tool is intentionally limited to the exact local tuple `emulator / syntholo-local / emulator / emulator-local`. The checked-in environment allowlist contains no live project or principal, production is disabled, and no launch-content decision file exists while the Product Bible specialization decision remains open. Do not add staging values, author launch curriculum, or perform a live write before the named owners complete that decision and supply the real deployment identities.

Run the isolated lifecycle gate:

```bash
./scripts/test_content_publication.sh
```

The runner uses the pinned Firebase CLI and Java 21, allocates non-default ephemeral Firestore, websocket, hub, and logging ports, requires exactly 38 passing tests with no failure, skip, or cancellation, and proves that all four ports close afterward. It covers first publication, immutable version heads, idempotent replay/collision, no-op auditing, roll-forward, exact rollback, corruption rejection, transaction-budget rejection, injected-failure atomicity, identity gates, and the exact-source secret scan.

For an interactive local preview, start the emulator in one terminal:

```bash
./node_modules/.bin/firebase emulators:start --project syntholo-local --only firestore
```

Then identify it explicitly and run the preview from a second terminal:

```bash
export FIRESTORE_EMULATOR_HOST=127.0.0.1:8080

npm run content:publish -- --dry-run \
  --operation-id 11111111-1111-4111-8111-111111111111 \
  --environment emulator \
  --project syntholo-local \
  --confirm-project syntholo-local \
  --source tests/fixtures/content/minimal-curriculum-v1.json
```

Replace `--dry-run` with `--apply` only against that local emulator. Every applied request needs a caller-generated lowercase RFC 4122 UUID; reuse an operation ID only to replay the exact same request. Rollback is catalog-rooted and requires a new operation ID plus `--catalog-pointer en-us --to-catalog-version <catalog-version-id>`. Both commands print only bounded operator metadata, IDs, counts, outcomes, and digests. Publish resolves and scans the exact source with the pinned repository gitleaks policy before Firebase Admin is imported or constructed.

For interactive Auth and Firestore development, use the pinned local CLI:

```bash
./node_modules/.bin/firebase emulators:start --project syntholo-local --only auth,firestore
```

Ordinary development builds, tests, and launches with `--ui-testing` use the non-secret `syntholo-local` project identity and connect to Auth on `127.0.0.1:9099` and Firestore on `127.0.0.1:8080`. No Firebase plist is required for those launches.

## Verify credential safety

The canonical content gate runs the pinned scanner over complete reachable history from a non-shallow clone and a snapshot of first-party worktree files, including ignored local configuration and logs. It prunes only Git metadata, independent `.worktrees`, the verified local gitleaks cache, dependency trees (`node_modules`), and build trees (`DerivedData` and `.build`); generated output and the final bundle are scanned explicitly:

```bash
./scripts/scan_secrets.sh --history --worktree
```

Generated diagnostics and a built `.app` are explicit release inputs rather than implicit repository paths:

```bash
./scripts/scan_secrets.sh --generated /absolute/path/to/generated-output
./scripts/scan_secrets.sh --bundle /absolute/path/to/Syntholo.app
```

Scanner output is fully redacted and temporary reports are removed. Bundle scans inspect ordinary files, printable strings extracted from every regular file (including Mach-O binaries), and property lists normalized to XML; symbolic links fail closed and require a resolved bundle. Nested archives are not expanded; if an archive is intentionally added to the app, review and scan its bounded extracted contents separately. Firebase's public iOS client configuration may be reviewed as public deployment metadata, but credentials, provider secrets, tokens, service-account keys, and private signing material are never allowlisted. The scanner's regression test plants high-entropy credential fixtures and proves detection independently in worktree, history, generated output, and app-bundle scopes, including a credential compiled into a Mach-O fixture.

Also confirm no Firebase plist or local configuration is tracked; filename checks supplement but do not replace content scanning:

```bash
git ls-files '*GoogleService-Info.plist' '*.firebase.plist' 'Config/Firebase.local.xcconfig'
```

The command must print nothing.

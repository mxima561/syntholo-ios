# Firebase setup

Firebase console files and provider identifiers are deployment configuration. Do not commit them.

## Register the iOS app

1. Create separate Firebase projects for development, staging, and production as needed.
2. In each project, register an Apple app with bundle identifier `com.syntholo.ios`.
3. Download `GoogleService-Info.plist`, rename it to match the environment (`development.firebase.plist`, `staging.firebase.plist`, or `production.firebase.plist`), and place it in `Syntholo/Resources/`.
4. Run `./scripts/bootstrap.sh` after adding or changing a plist so XcodeGen includes it in the app resources.

The environment plist files, the original `GoogleService-Info.plist`, and `Config/Firebase.local.xcconfig` are ignored by Git. The app shows a setup-safe state when the selected environment has no bundled plist.

## Enable authentication providers

In Firebase Console → Authentication → Sign-in method, enable:

- Apple
- Google
- Email/Password

For Apple, add the **Sign in with Apple** capability to the `Syntholo` target and complete the Apple/Firebase key and redirect-domain configuration. Do not place the Apple private key in this repository.

For Google, copy `Config/Firebase.example.xcconfig` to the ignored `Config/Firebase.local.xcconfig`. Set `GOOGLE_REVERSED_CLIENT_SCHEME` to the `REVERSED_CLIENT_ID` value from the environment plist, then expose that setting as the app's URL scheme when the Google sign-in integration is added. Never commit the live reversed client ID.

## Run local emulators

Install the Firebase CLI, authenticate if the CLI requests it, and start Auth and Firestore:

```bash
npm install --global firebase-tools
firebase emulators:start --project syntholo-local --only auth,firestore
```

Tests and launches with `--ui-testing` use the non-secret `syntholo-local` project identity and connect to Auth on `127.0.0.1:9099` and Firestore on `127.0.0.1:8080`. No production plist is required for those launches.

## Verify credential safety

Before committing, confirm no Firebase plist or local configuration is tracked:

```bash
git ls-files '*GoogleService-Info.plist' '*.firebase.plist' 'Config/Firebase.local.xcconfig'
```

The command must print nothing.

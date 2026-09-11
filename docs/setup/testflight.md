# Getting a TestFlight build out

What it takes to put the current app in front of testers. This covers the
build and upload path only. It does not claim the app is feature-complete:
Learn is still a read-only preview, and Practice, Social, and Profile are
"coming soon" scaffolds. That is fine for internal testing, and it is worth
saying out loud to testers so their feedback lands on what exists.

## What has to be true before the first upload

| Requirement | Status | Who |
|---|---|---|
| App icon | Done - `Syntholo/Resources/Assets.xcassets/AppIcon.appiconset` | - |
| Privacy manifest | Done - `Syntholo/Resources/PrivacyInfo.xcprivacy` | - |
| Apple Developer Program membership | Needed | You |
| Signing certificate on this Mac | Needed | You |
| At least one registered device on the team | Needed | You |
| `SYNTHOLO_DEVELOPMENT_TEAM` set | Needed | You |
| Firebase iOS config installed | Needed | You |
| App record in App Store Connect | Needed | You |

Being enrolled is not the same as being able to sign here. Xcode issues the
signing certificate to a specific Mac the first time you add the account and
build for a device. Check with:

```bash
security find-identity -v -p codesigning
```

An empty list means no certificate exists on this machine yet, whatever the
website shows. `xcodebuild ... archive` fails with "Signing for Syntholo
requires a development team" until that is fixed.

## 1. Sign in to Xcode and set the team

Xcode -> Settings -> Accounts -> **+** -> Apple ID. Add the account that holds
the membership, then select the team and let Xcode download the certificate.

Copy the Team ID from that screen (10 characters) into a local, ignored file:

```bash
cp Config/Signing.example.xcconfig Config/Signing.local.xcconfig
```

Edit it so `SYNTHOLO_DEVELOPMENT_TEAM` holds your Team ID, then regenerate:

```bash
xcodegen generate
```

`Config/Signing.local.xcconfig` is gitignored on purpose. The Team ID is not
a secret, but it is per-developer, and pinning it in `project.yml` would break
every other machine.

### Register a device first, even for TestFlight

A brand-new team has no registered devices, and that blocks archiving:

```
error: Communication with Apple failed: Your team has no devices from which
to generate a provisioning profile.
error: No profiles for 'com.syntholo.ios' were found: Xcode couldn't find any
iOS App Development provisioning profiles matching 'com.syntholo.ios'.
```

This surprises people, because TestFlight distribution does not itself need a
registered device. The reason is the archive step: Xcode's automatic signing
builds the archive with a **development** identity and only re-signs for
distribution during export. Apple will not issue that development profile to a
team with zero devices.

Fix it either way:

- Connect the iPhone over USB, then Xcode -> Window -> Devices and Simulators.
  Xcode registers it, and this is worth doing regardless since you will want
  to run on a real device.
- Or add a UDID by hand at
  https://developer.apple.com/account/resources/devices/list

Do not set `CODE_SIGN_IDENTITY` to `Apple Distribution` to sidestep this. With
`CODE_SIGN_STYLE: Automatic` it fails with "conflicting provisioning
settings" - the archive is meant to be development-signed.

## 2. Install the Firebase config

The app does not read `GoogleService-Info.plist` by that name. It looks up
`<environment>.firebase` in the bundle, and Release builds set
`SYNTHOLO_ENV = production`. Without that file the app boots straight to the
"setup required" screen - it does not crash, which is exactly why this is easy
to ship by accident.

In the Firebase console: Project settings -> Your apps -> iOS. The bundle ID
must be `com.syntholo.ios`. Download the plist, then:

```bash
scripts/install_firebase_config.sh ~/Downloads/GoogleService-Info.plist production
```

The script validates the file against the same rules the app applies at launch
and refuses a config for the wrong bundle ID. It also writes
`Config/Firebase.local.xcconfig` so Google sign-in gets its client ID.

Enable the sign-in providers you intend to test under Authentication ->
Sign-in method. Email/Password and Apple are the two the app depends on;
Google needs its client ID present, which the script handles.

Then regenerate so the new resource is bundled:

```bash
xcodegen generate
```

Verify it took, on a simulator build:

```bash
xcodebuild -project Syntholo.xcodeproj -scheme Syntholo -configuration Release \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build
```

If the app still shows "setup required", the plist did not make it into the
bundle - check that it sits at `Syntholo/Resources/production.firebase.plist`
and that `xcodegen generate` ran after it was added.

## 3. Create the App Store Connect record

At appstoreconnect.apple.com -> Apps -> **+** -> New App:

- Platform: iOS
- Bundle ID: `com.syntholo.ios` (register it under Certificates, Identifiers &
  Profiles first if it is not in the list)
- SKU: anything stable, e.g. `syntholo-ios`

Enable **Sign in with Apple** on that identifier - the app ships the
`com.apple.developer.applesignin` entitlement, and the upload is rejected if
the identifier does not have the capability.

## 4. Archive and upload

Bump `CURRENT_PROJECT_VERSION` in `Config/Shared.xcconfig` for every upload;
App Store Connect rejects a duplicate build number.

```bash
xcodebuild -project Syntholo.xcodeproj -scheme Syntholo -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/Syntholo.xcarchive archive
```

Then Xcode -> Window -> Organizer -> Archives -> Distribute App -> TestFlight
Internal Only. The Organizer route handles upload and authentication without
needing an App Store Connect API key.

For internal testers, no App Review is required. External testing needs
Beta App Review plus a privacy policy URL and test notes.

## Expect these on the first upload

Apple emails warnings after processing. Two are likely and neither blocks
internal testing:

- **Missing purpose strings** - only if a dependency touches a protected API.
  The app itself requests nothing that needs one today.
- **ITMS-90683 / privacy manifest notices** - the first-party manifest is in
  place; check the aggregated privacy report in the Organizer if a notice
  names a dependency.

## What testers can actually do

Worth pasting into the TestFlight test notes so feedback is useful:

- Complete onboarding: age, goal, experience, path, coach, account.
- Create an account with email, Apple, or Google.
- Sign back in with email, including password reset.
- Browse programs, modules, and lesson previews.

Lessons are **read-only previews** - answers are not collected yet. Practice,
Social, and Profile are placeholders. There is no subscription flow.

#!/usr/bin/env bash
# Archives and exports a signed App Store IPA ready for TestFlight upload.
#
# Usage: scripts/archive_for_testflight.sh [output-directory]
#        defaults to ./build
#
# Does not upload. Hand the IPA to Xcode's Organizer, or to
# `xcrun altool`/`notarytool`, once you have checked it.

set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
output_directory="${1:-$REPO_ROOT/build}"
archive_path="$output_directory/Syntholo.xcarchive"
export_path="$output_directory/export"

cd "$REPO_ROOT"

team_id="$(
    xcodebuild -project Syntholo.xcodeproj -target Syntholo \
        -configuration Release -showBuildSettings 2>/dev/null \
        | awk '$1 == "DEVELOPMENT_TEAM" { print $3 }' | head -1
)"
if [[ -z "$team_id" ]]; then
    echo "error: DEVELOPMENT_TEAM is empty." >&2
    echo "       cp Config/Signing.example.xcconfig Config/Signing.local.xcconfig" >&2
    echo "       and set SYNTHOLO_DEVELOPMENT_TEAM to your Team ID." >&2
    exit 1
fi

# Without this the Release build cannot resolve Firebase: FirebaseBootstrap
# returns false and every tester lands on the setup-required screen. That is
# not a build failure, so it would archive, export and upload perfectly
# cleanly - which is exactly why this refuses to continue rather than warn.
if [[ ! -f "$REPO_ROOT/Syntholo/Resources/production.firebase.plist" ]]; then
    if [[ "${SYNTHOLO_ALLOW_UNCONFIGURED_ARCHIVE:-0}" == "1" ]]; then
        echo "WARNING: archiving without production.firebase.plist because" >&2
        echo "         SYNTHOLO_ALLOW_UNCONFIGURED_ARCHIVE=1. Do not upload" >&2
        echo "         the result to TestFlight." >&2
        echo >&2
    else
        echo "error: Syntholo/Resources/production.firebase.plist is missing." >&2
        echo "       Install it with scripts/install_firebase_config.sh first." >&2
        echo "       To archive anyway (signing checks only, not for testers)," >&2
        echo "       set SYNTHOLO_ALLOW_UNCONFIGURED_ARCHIVE=1." >&2
        exit 1
    fi
fi

echo "Archiving for team $team_id."
rm -rf "$archive_path" "$export_path"
mkdir -p "$output_directory"

xcodebuild \
    -project Syntholo.xcodeproj \
    -scheme Syntholo \
    -configuration Release \
    -destination 'generic/platform=iOS' \
    -archivePath "$archive_path" \
    -allowProvisioningUpdates \
    archive

export_options="$output_directory/ExportOptions.plist"
cat > "$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>$team_id</string>
    <key>uploadSymbols</key>
    <true/>
    <key>destination</key>
    <string>export</string>
</dict>
</plist>
EOF

echo "Exporting signed App Store IPA."
xcodebuild -exportArchive \
    -archivePath "$archive_path" \
    -exportOptionsPlist "$export_options" \
    -exportPath "$export_path" \
    -allowProvisioningUpdates

ipa="$export_path/Syntholo.ipa"
echo
echo "IPA: $ipa"

# codesign cannot read a .ipa directly - it is a zip, not a bundle - so unpack
# the app to confirm the export really re-signed for distribution.
verify_root="$(mktemp -d)"
trap 'rm -rf "$verify_root"' EXIT
if unzip -q "$ipa" -d "$verify_root"; then
    verify_app="$verify_root/Payload/Syntholo.app"
    codesign -dvvv "$verify_app" 2>&1 \
        | grep -E "^Authority=Apple Distribution" \
        || echo "WARNING: the IPA is not signed by Apple Distribution." >&2
    if [[ -f "$verify_app/production.firebase.plist" ]]; then
        echo "firebase project: $(
            /usr/libexec/PlistBuddy -c "Print :PROJECT_ID" \
                "$verify_app/production.firebase.plist" 2>/dev/null
        )"
    else
        echo "WARNING: no production.firebase.plist inside the IPA." >&2
    fi
fi
echo
echo "Remember to bump CURRENT_PROJECT_VERSION in Config/Shared.xcconfig"
echo "before the next upload - App Store Connect rejects duplicate builds."

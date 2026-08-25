#!/bin/bash
# Builds, signs, notarizes, staples, and publishes a release DMG.
#
# Usage: scripts/release.sh <notarytool-keychain-profile> [--no-publish]
#
# Runs entirely on this machine — signing keys and notary credentials never
# go to CI. Requires: full Xcode, a "Developer ID Application" identity in
# the keychain, a stored notarytool profile (xcrun notarytool
# store-credentials), and an authenticated gh CLI for the publish step.
set -euo pipefail
cd "$(dirname "$0")/.."

PROFILE="${1:?Usage: scripts/release.sh <notarytool-keychain-profile> [--no-publish]}"
PUBLISH=true
[ "${2:-}" = "--no-publish" ] && PUBLISH=false

# Version comes from MARKETING_VERSION in project.yml.
VERSION=$(awk '/MARKETING_VERSION/{gsub(/"/,"",$2); print $2; exit}' project.yml)
[ -n "$VERSION" ] || { echo "Could not read MARKETING_VERSION from project.yml" >&2; exit 1; }
DMG="build/Deadlines-$VERSION.dmg"

# 1. Confirm identity and notary profile. Use the identity's full name, not
#    a hash, so the script survives certificate renewal.
IDENTITY=$(security find-identity -v -p codesigning | awk -F'"' '/Developer ID Application/{print $2; exit}')
[ -n "$IDENTITY" ] || { echo "No Developer ID Application identity in the keychain" >&2; exit 1; }
echo "Signing as: $IDENTITY"
xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null \
    || { echo "Notary profile '$PROFILE' not usable" >&2; exit 1; }

if $PUBLISH; then
    gh auth status >/dev/null 2>&1 || { echo "gh is not authenticated" >&2; exit 1; }
fi

rm -rf build
./scripts/generate.sh

# 2–3. Archive Release. Hardened runtime and manual Developer ID signing are
#      set in project.yml for all configurations.
xcodebuild -scheme Deadlines -configuration Release archive \
    -archivePath build/Deadlines.xcarchive \
    CODE_SIGN_IDENTITY="$IDENTITY"

# 4. Export with developer-id method.
xcodebuild -exportArchive \
    -archivePath build/Deadlines.xcarchive \
    -exportOptionsPlist scripts/ExportOptions.plist \
    -exportPath build/export

APP="build/export/Deadlines.app"

# 5. Verify signatures and entitlements on the app and the embedded appex.
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements - "$APP" | grep -q application-groups \
    || { echo "App Group entitlement missing from app" >&2; exit 1; }
codesign -d --entitlements - "$APP/Contents/Extensions/DeadlinesWidget.appex" | grep -q application-groups \
    || { echo "App Group entitlement missing from widget" >&2; exit 1; }
codesign -d -vv "$APP" 2>&1 | grep -q "flags=0x10000(runtime)" \
    || { echo "Hardened runtime not enabled on app" >&2; exit 1; }

# 6. Build the DMG: app + /Applications symlink.
rm -rf build/staging
mkdir -p build/staging
cp -R "$APP" build/staging/
ln -s /Applications build/staging/Applications
hdiutil create -volname Deadlines -srcfolder build/staging -ov -format UDZO "$DMG"

# 7. Sign the DMG.
codesign --sign "$IDENTITY" --timestamp "$DMG"

# 8. Notarize. On failure: xcrun notarytool log <id> --keychain-profile <profile>
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

# 9. Staple and validate.
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature -v "$DMG"

echo "Release artifact ready: $DMG"

# 10. Tag and publish.
if $PUBLISH; then
    git tag "v$VERSION"
    git push origin main "v$VERSION"
    gh release create "v$VERSION" "$DMG" \
        --title "Deadlines $VERSION" \
        --notes-file CHANGELOG.md
    echo "Published release v$VERSION"
else
    echo "Skipped publish (--no-publish)"
fi

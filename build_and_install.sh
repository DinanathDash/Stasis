#!/bin/bash
set -e

APP_PATH="build/Build/Products/Debug/Stasis.app"
CHARGING_HELPER_PATH="$APP_PATH/Contents/Library/LaunchServices/com.dinanathdash.stasis.charging-helper"

echo "Building Stasis..."
xcodebuild \
    -scheme stasis \
    -configuration Debug \
    -derivedDataPath ./build \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=YES \
    CODE_SIGNING_ALLOWED=YES

echo "Signing Stasis for local Service Management registration..."
codesign --force --sign - "$CHARGING_HELPER_PATH"
codesign --force --deep --sign - "$APP_PATH"
codesign --force --sign - -r req.txt "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "Killing existing Stasis processes..."
pkill -f "stasis.app/Contents/MacOS/stasis" || true
# Alternatively, match the app name exactly:
pkill -x "stasis" || true
pkill -x "Stasis" || true
sleep 1

echo "Removing old Stasis from /Applications..."
rm -rf /Applications/Stasis.app

echo "Copying new Stasis to /Applications..."
cp -R build/Build/Products/Debug/stasis.app /Applications/Stasis.app

echo "Registering app with Launch Services & resetting App Intents cache..."
xattr -cr /Applications/Stasis.app 2>/dev/null || true
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/Stasis.app 2>/dev/null || true
killall -9 shortcutsd intentsd 2>/dev/null || true
sleep 1

echo "Launching new Stasis app..."
open /Applications/Stasis.app

echo "Done!"

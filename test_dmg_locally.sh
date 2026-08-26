#!/bin/bash
set -e

echo "Building local test DMG..."

# If you haven't built the app yet, uncomment the line below to build it first.
# xcodebuild -scheme stasis -configuration Debug -derivedDataPath ./build -quiet

rm -rf build_local_dmg
mkdir -p build_local_dmg/dmg_root
cp -R build/Build/Products/Debug/stasis.app build_local_dmg/dmg_root/Stasis.app

cd build_local_dmg
rm -f ../Stasis_Local_Test.dmg

echo "Creating DMG..."
create-dmg \
  --volname "Stasis" \
  --volicon "dmg_root/Stasis.app/Contents/Resources/Stasis.icns" \
  --window-pos 380 250 \
  --window-size 600 460 \
  --icon-size 130 \
  --background "../assets/dmg-background.png" \
  --icon "Stasis.app" 132 200 \
  --hide-extension "Stasis.app" \
  --app-drop-link 458 200 \
  "../Stasis_Local_Test.dmg" \
  "dmg_root"

cd ..
echo "Opening DMG..."
open Stasis_Local_Test.dmg

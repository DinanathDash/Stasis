#!/bin/bash
set -e

echo "Building Stasis..."
xcodebuild -scheme stasis -configuration Debug -derivedDataPath ./build

echo "Killing existing Stasis processes and WidgetKit daemons..."
pkill -f "StasisWidgets" || true
pkill -x "Stasis" || true
pkill -x "stasis" || true
pkill -x "chronod" || true
pkill -x "NotificationCenter" || true
sleep 1

echo "Removing old Stasis from /Applications..."
rm -rf /Applications/Stasis.app

echo "Copying new Stasis to /Applications..."
cp -R build/Build/Products/Debug/stasis.app /Applications/Stasis.app

echo "Registering with LaunchServices and PlugInKit..."
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted /Applications/Stasis.app || true
pluginkit -r /Applications/Stasis.app/Contents/PlugIns/StasisWidgets.appex || true
pluginkit -a /Applications/Stasis.app/Contents/PlugIns/StasisWidgets.appex || true
pluginkit -e use -i com.dinanathdash.stasis.widgets || true

echo "Restarting WidgetKit timelines and launching new Stasis app..."
pkill -x "chronod" || true
pkill -x "NotificationCenter" || true
sleep 1
open /Applications/Stasis.app

echo "Done!"

#!/usr/bin/env bash

DERIVED_DATA="$(du -s ~/Library/Developer/Xcode/DerivedData/ | cut -f1)"
#ARCHIVES="$(du -s ~/Library/Developer/Xcode/Archives | cut -f1)"
#SIMULATOR_DATA="$(du -s ~/Library/Developer/CoreSimulator | cut -f1)"
#XCODE_CACHE="$(du -s ~/Library/Caches/com.apple.dt.Xcode | cut -f1)"
#CARTHAGE_CACHE="$(du -s ~/Library/Caches/org.carthage.CarthageKit | cut -f1)"
#DEVICE_SUPPORT_IOS="$(du -s ~/Library/Developer/Xcode/iOS\ DeviceSupport | cut -f1)"
#DEVICE_SUPPORT_WATHOS="$(du -s ~/Library/Developer/Xcode/watchOS\ DeviceSupport | cut -f1)"
#DEVICE_SUPPORT_TVOS="$(du -s ~/Library/Developer/Xcode/tvOS\ DeviceSupport | cut -f1)"

#SUM=$((DERIVED_DATA + ARCHIVES + SIMULATOR_DATA + XCODE_CACHE + CARTHAGE_CACHE + DEVICE_SUPPORT_IOS + DEVICE_SUPPORT_WATHOS + DEVICE_SUPPORT_TVOS))

SUM=$((DERIVED_DATA))

echo "$SUM"

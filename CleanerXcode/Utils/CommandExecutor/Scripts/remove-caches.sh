#!/usr/bin/env bash

rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Caches/org.carthage.CarthageKit

if command -v pod  &> /dev/null
then
    pod cache clean --all
fi

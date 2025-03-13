#!/usr/bin/env bash

echo "Removing old simulators..."
xcrun simctl delete unavailable
echo "Done!"

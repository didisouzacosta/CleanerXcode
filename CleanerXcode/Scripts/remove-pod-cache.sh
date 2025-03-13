#!/usr/bin/env bash

if command -v pod  &> /dev/null
then
    echo "Removing pod cache..."
    pod cache clean --all
    echo "Done!"
fi

#!/usr/bin/env bash

paths=(
    "derived_data $HOME/Library/Developer/Xcode/DerivedData/"
    "archives $HOME/Library/Developer/Xcode/Archives"
    "simulator_data $HOME/Library/Developer/CoreSimulator"
    "xcode_cache $HOME/Library/Caches/com.apple.dt.Xcode"
    "carthage_cache $HOME/Library/Caches/org.carthage.CarthageKit"
    "device_support_ios $HOME/Library/Developer/Xcode/iOS\ DeviceSupport"
    "device_support_watchos $HOME/Library/Developer/Xcode/watchOS\ DeviceSupport"
    "device_support_tvos $HOME/Library/Developer/Xcode/tvOS\ DeviceSupport"
)

infos=()

for path in "${paths[@]}"; do
    read -a item <<< "$path"

    reference="${item[0]}"
    path="${item[1]}"

    if [ -d "${path}" ];
    then
        size=$(du -sk "${path}" | cut -f1)
        infos+=("${reference} ${size}")
    else
        infos+=("${reference} 0")
    fi
done

jsonString=""

for info in "${infos[@]}"; do
    read -a item <<< "$info"
    
    if [ "$jsonString" != "" ];
    then
        jsonString+=","
    fi

    jsonString+="\"${item[0]}\": ${item[1]}"
done

echo "{${jsonString}}"

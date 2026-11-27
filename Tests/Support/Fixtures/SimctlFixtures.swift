//
//  SimctlFixtures.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

/// Sanitized outputs of `simctl` (Xcode 27.2): real field names, invented UDIDs and paths.
nonisolated enum SimctlFixtures {

    // MARK: - Public Properties

    static let devices = """
    {
      "devices" : {
        "com.apple.CoreSimulator.SimRuntime.iOS-27-2" : [
          {
            "dataPath" : "/Users/qa/Library/Developer/CoreSimulator/Devices/AAAA0000-0000-0000-0000-000000000001/data",
            "dataPathSize" : 7115542528,
            "logPath" : "/Users/qa/Library/Logs/CoreSimulator/AAAA0000-0000-0000-0000-000000000001",
            "udid" : "AAAA0000-0000-0000-0000-000000000001",
            "lastUsedAt" : "2026-10-30T17:48:39Z",
            "isAvailable" : true,
            "logPathSize" : 675840,
            "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro",
            "state" : "Booted",
            "name" : "iPhone 18 Pro"
          },
          {
            "dataPath" : "/Users/qa/Library/Developer/CoreSimulator/Devices/AAAA0000-0000-0000-0000-000000000002/data",
            "udid" : "AAAA0000-0000-0000-0000-000000000002",
            "isAvailable" : true,
            "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPhone-18-Pro",
            "state" : "Shutdown",
            "name" : "iPhone 18 Pro (2)"
          }
        ],
        "com.apple.CoreSimulator.SimRuntime.iOS-26-0" : [
          {
            "dataPath" : "/Users/qa/Library/Developer/CoreSimulator/Devices/AAAA0000-0000-0000-0000-000000000003/data",
            "dataPathSize" : 1000,
            "logPath" : "/Users/qa/Library/Logs/CoreSimulator/AAAA0000-0000-0000-0000-000000000003",
            "udid" : "AAAA0000-0000-0000-0000-000000000003",
            "lastUsedAt" : "2026-01-02T03:04:05Z",
            "isAvailable" : false,
            "logPathSize" : 24,
            "deviceTypeIdentifier" : "com.apple.CoreSimulator.SimDeviceType.iPad-Air-11-inch-M3",
            "state" : "Shutdown",
            "name" : "iPad Air"
          }
        ]
      }
    }

    """

    static let runtimes = """
    {
      "BBBB0000-0000-0000-0000-000000000001" : {
        "build" : "24A94425",
        "deletable" : true,
        "identifier" : "BBBB0000-0000-0000-0000-000000000001",
        "kind" : "Patchable Cryptex Disk Image",
        "lastUsedAt" : "2026-10-29T19:18:42Z",
        "mountPath" : "/private/var/run/com.apple.security.cryptexd/mnt/com.apple.iPhoneOS.SimulatorRuntime-v24.1",
        "path" : "/System/Library/AssetsV2/com_apple_MobileAsset_iOSSimulatorRuntime/0000.asset/AssetData",
        "platformIdentifier" : "com.apple.platform.iphonesimulator",
        "runtimeIdentifier" : "com.apple.CoreSimulator.SimRuntime.iOS-27-1",
        "signatureState" : "Unknown",
        "sizeBytes" : 7874743137,
        "state" : "Ready",
        "supportedArchitectures" : [ "arm64" ],
        "version" : "27.1"
      },
      "BBBB0000-0000-0000-0000-000000000002" : {
        "build" : "23A339",
        "deletable" : false,
        "identifier" : "BBBB0000-0000-0000-0000-000000000002",
        "kind" : "Bundled with Xcode",
        "platformIdentifier" : "com.apple.platform.xrsimulator",
        "runtimeIdentifier" : "com.apple.CoreSimulator.SimRuntime.xrOS-26-0",
        "sizeBytes" : 1200,
        "state" : "Ready",
        "version" : "26.0"
      }
    }

    """

}

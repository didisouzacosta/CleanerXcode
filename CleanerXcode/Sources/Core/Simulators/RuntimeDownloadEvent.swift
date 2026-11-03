//
//  RuntimeDownloadEvent.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

/// A step of a runtime download, read from the output of `xcodebuild -downloadPlatform` (C34).
nonisolated enum RuntimeDownloadEvent: Sendable, Equatable {
    case preparing
    case downloading(RuntimeDownloadAmount)
    /// The download ended and the runtime is being imported.
    case installing
    case completed
}

/// How much of the runtime arrived, as `xcodebuild` prints it (bytes quantized to about 3 digits).
nonisolated struct RuntimeDownloadAmount: Sendable, Equatable {
    /// From 0 to 1, from the printed percentage.
    let fraction: Double
    let receivedBytes: Int64
    let totalBytes: Int64
}

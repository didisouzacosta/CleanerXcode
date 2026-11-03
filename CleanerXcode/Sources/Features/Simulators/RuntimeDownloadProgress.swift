//
//  RuntimeDownloadProgress.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/11/26.
//

/// The progress of the runtime being downloaded, when its output shows it (C34).
struct RuntimeDownloadProgress: Equatable {

    // MARK: - Public Properties

    let phase: Phase
    /// Only while downloading, once the estimate is reliable.
    let remaining: RuntimeDownloadRemaining?

    // MARK: - Nested Types

    enum Phase: Equatable {
        case preparing
        case downloading(fraction: Double)
        case installing
    }

}

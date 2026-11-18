//
//  RuntimeDownloadOutcome.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// How the download of one platform of the queue ended.
enum RuntimeDownloadOutcome: Equatable {
    case installed
    case failed(CleanupError)
    /// Cancelled: the platform being downloaded and the queued ones.
    case notDownloaded
}

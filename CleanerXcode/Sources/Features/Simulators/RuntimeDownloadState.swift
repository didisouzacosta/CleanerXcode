//
//  RuntimeDownloadState.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// The runtime downloads of the "Simulators and runtimes" page (C30, A1). A finished queue stays
/// until the page disappears or the next queue starts.
enum RuntimeDownloadState: Equatable {

    // MARK: - Cases

    case idle
    case downloading(RuntimeDownloadRun)
    case finished(RuntimeDownloadRun)

    // MARK: - Public Properties

    var isDownloading: Bool {
        if case .downloading = self {
            true
        } else {
            false
        }
    }

    var isFinished: Bool {
        if case .finished = self {
            true
        } else {
            false
        }
    }

}

//
//  RuntimeDownloadChoice.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

/// The platforms chosen in the "Download runtimes" sheet (C30, A1). It opens with nothing selected,
/// so no download of several GB starts by pre-selection (Q9).
struct RuntimeDownloadChoice: Identifiable, Equatable {

    // MARK: - Public Properties

    /// One sheet at a time.
    let id = "runtime-download"

    private(set) var selected: Set<RuntimePlatform> = []

    /// In the order of `RuntimePlatform.allCases`.
    var orderedSelection: [RuntimePlatform] {
        RuntimePlatform.allCases.filter(selected.contains)
    }

    // MARK: - Initializers

    init() {}

    // MARK: - Public Methods

    mutating func toggle(_ platform: RuntimePlatform) {
        if selected.contains(platform) {
            selected.remove(platform)
        } else {
            selected.insert(platform)
        }
    }

}

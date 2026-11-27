//
//  CleanupTarget.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

nonisolated struct CleanupTarget: Sendable, Hashable {

    // MARK: - Public Properties

    let root: URL
    /// Direct children of `root` that are never removed nor measured.
    let excludedNames: Set<String>

    // MARK: - Initializers

    init(root: URL, excludedNames: Set<String> = []) {
        self.root = root
        self.excludedNames = excludedNames
    }

}

//
//  WatchedCategoryRoots.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// The folders the live measurement watches, and which categories a changed folder touches
/// (C40 · tempo real, R2, R7). Only existing folders that are not symbolic links are watched, by
/// their real path; the mapping knows the roots of every observed category, watched or not.
/// Paths compare as Swift strings (Unicode equivalence, never bytes) and in lowercase, since the
/// default APFS volume ignores case, and only on whole components.
nonisolated struct WatchedCategoryRoots: Equatable, Sendable {

    // MARK: - Public Properties

    /// Real paths without a trailing slash, without duplicates and sorted.
    let directories: [String]

    // MARK: - Private Properties

    private let targets: [Target]

    // MARK: - Public Static Methods

    static func resolve(
        categories: [CleanupCategory],
        observing ids: Set<CleanupCategoryID>,
        existingDirectory: (URL) -> String?
    ) -> WatchedCategoryRoots {
        var directories: Set<String> = []
        var targets: [Target] = []

        for category in categories where ids.contains(category.id) {
            for target in category.targets {
                let existing = existingDirectory(target.root).map(withoutTrailingSlash)

                var roots = [withoutTrailingSlash(target.root.path(percentEncoded: false)).lowercased()]

                if let existing {
                    directories.insert(existing)
                    roots.append(existing.lowercased())
                }

                targets.append(Target(
                    categoryID: category.id,
                    roots: roots,
                    excludedNames: Set(target.excludedNames.map { $0.lowercased() })
                ))
            }
        }

        return WatchedCategoryRoots(directories: directories.sorted(), targets: targets)
    }

    /// The real path of an existing folder that is not a symbolic link, `nil` otherwise. It uses
    /// `realpath(3)`, which keeps `/private`, unlike `resolvingSymlinksInPath()`.
    static func existingDirectory(_ url: URL) -> String? {
        let path = withoutTrailingSlash(url.path(percentEncoded: false))
        let plain = URL(filePath: path, directoryHint: .notDirectory)

        guard
            let values = try? plain.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]),
            values.isSymbolicLink == false,
            values.isDirectory == true
        else {
            return nil
        }

        guard let resolved = realpath(path, nil) else { return nil }

        defer { free(resolved) }

        return String(cString: resolved)
    }

    // MARK: - Private Static Methods

    private static func withoutTrailingSlash(_ path: String) -> String {
        path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    /// What follows `root` in `path`: empty for the root itself, `nil` outside it.
    private static func relativePath(of path: String, under root: String) -> Substring? {
        if path == root {
            return ""
        }

        let prefix = root == "/" ? root : root + "/"

        guard path.hasPrefix(prefix) else { return nil }

        return path.dropFirst(prefix.count)
    }

    // MARK: - Public Methods

    func categories(affectedBy changes: [FileSystemChange]) -> Set<CleanupCategoryID> {
        var affected: Set<CleanupCategoryID> = []

        for change in changes {
            let path = Self.withoutTrailingSlash(change.path).lowercased()

            for target in targets where target.isAffected(by: path, kind: change.kind) {
                affected.insert(target.categoryID)
            }
        }

        return affected
    }

    func needsRewatch(_ changes: [FileSystemChange]) -> Bool {
        changes.contains { $0.kind == .rootChanged }
    }

    // MARK: - Nested Types

    private struct Target: Equatable {

        // MARK: - Public Properties

        let categoryID: CleanupCategoryID
        /// The catalog path and, when the folder exists, its real path, in lowercase.
        let roots: [String]
        let excludedNames: Set<String>

        // MARK: - Public Methods

        /// A change touches the root or what is below it, except the excluded children; a root
        /// change or a rescan touches every root at, above or below the path, with no exclusions.
        func isAffected(by path: String, kind: FileSystemChange.Kind) -> Bool {
            roots.contains { root in
                switch kind {
                case .changed:
                    guard let relative = WatchedCategoryRoots.relativePath(of: path, under: root) else {
                        return false
                    }

                    let child = relative.split(separator: "/").first.map(String.init)

                    return child.map { !excludedNames.contains($0) } ?? true

                case .rootChanged, .mustRescan:
                    return WatchedCategoryRoots.relativePath(of: path, under: root) != nil
                        || WatchedCategoryRoots.relativePath(of: root, under: path) != nil
                }
            }
        }

    }

}

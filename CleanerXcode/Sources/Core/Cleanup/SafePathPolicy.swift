//
//  SafePathPolicy.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// Every path is checked here right before it is removed.
///
/// - `.unsafePath` means the caller built a path it must never remove: a bug, always reported.
/// - `.unsupportedRoot` means the root on this Mac cannot be cleaned safely (for example a symlink
///   to an external disk or to the home folder): the target is skipped.
/// - `.notFound` means the item disappeared: it is skipped.
nonisolated struct SafePathPolicy: Sendable {

    // MARK: - Public Properties

    let roots: [URL]
    let protectedPaths: [URL]
    /// Every resolved root must stay inside one of these folders.
    let allowedBases: [URL]

    // MARK: - Private Properties

    private let inspector: any PathInspecting
    private let resolvedRoots: [[String]]
    private let resolvedProtectedPaths: [[String]]
    private let resolvedAllowedBases: [[String]]

    // MARK: - Initializers

    init(
        roots: [URL],
        protectedPaths: [URL],
        allowedBases: [URL],
        inspector: any PathInspecting = FileSystemPathInspector()
    ) {
        precondition(
            (roots + protectedPaths + allowedBases).allSatisfy(Self.isAbsolute),
            "SafePathPolicy only accepts absolute file URLs."
        )

        self.roots = roots
        self.protectedPaths = protectedPaths
        self.allowedBases = allowedBases
        self.inspector = inspector
        self.resolvedRoots = roots.map(Self.resolvedComponents)
        self.resolvedProtectedPaths = protectedPaths.map(Self.resolvedComponents)
        self.resolvedAllowedBases = allowedBases.map(Self.resolvedComponents)
    }

    // MARK: - Private Static Methods

    private static func isAbsolute(_ url: URL) -> Bool {
        url.isFileURL && url.baseURL == nil && url.path(percentEncoded: false).hasPrefix("/")
    }

    private static func resolvedComponents(of url: URL) -> [String] {
        url.standardizedFileURL.resolvingSymlinksInPath().pathComponents
    }

    /// Resolves the parent folders but not the item, so a symlink item is judged by where it lives.
    private static func itemComponents(of url: URL) -> [String] {
        let standardized = url.standardizedFileURL

        return resolvedComponents(of: standardized.deletingLastPathComponent()) + [standardized.lastPathComponent]
    }

    // MARK: - Public Methods

    /// Checks the root once per target. The root itself is never followed when it is a symlink, and
    /// once its ancestors are resolved it must stay inside an allowed base without containing a
    /// protected path. Returns the resolved root components.
    @discardableResult
    func validateRoot(_ target: CleanupTarget) throws(CleanupError) -> [String] {
        let lexicalRoot = target.root.standardizedFileURL.pathComponents

        guard roots.contains(where: { $0.standardizedFileURL.pathComponents == lexicalRoot }) else {
            throw .unsafePath
        }

        let resolvedRoot = Self.resolvedComponents(of: target.root)

        guard
            !inspector.isSymbolicLink(target.root),
            resolvedAllowedBases.contains(where: { resolvedRoot.starts(with: $0) }),
            !resolvedProtectedPaths.contains(where: { $0.starts(with: resolvedRoot) })
        else { throw .unsupportedRoot }

        return resolvedRoot
    }

    /// Accepts `url` only when it:
    /// - is a strict descendant of the target root, without `.` or `..` components;
    /// - is not excluded by the target nor inside another catalog root;
    /// - is not reached through a symlinked folder that leaves the root;
    /// - exists and lives on the root's volume.
    ///
    /// The root never contains a protected path. A symlink item itself is accepted: only the link is
    /// removed.
    func validate(_ url: URL, in target: CleanupTarget) throws(CleanupError) {
        let rootComponents = try validateRoot(target)

        guard Self.isAbsolute(url), !url.pathComponents.contains(where: { $0 == "." || $0 == ".." }) else {
            throw .unsafePath
        }

        let item = Self.itemComponents(of: url)
        let nestedRoots = resolvedRoots.filter { $0.count > rootComponents.count && $0.starts(with: rootComponents) }

        guard
            item.count > rootComponents.count,
            item.starts(with: rootComponents),
            !target.excludedNames.contains(item[rootComponents.count]),
            !nestedRoots.contains(where: { item.starts(with: $0) })
        else { throw .unsafePath }

        guard inspector.exists(url) else { throw .notFound }

        if !inspector.isSymbolicLink(url) {
            guard let volume = inspector.volumeURL(of: url), volume == inspector.volumeURL(of: target.root) else {
                throw .unsafePath
            }
        }
    }

}

nonisolated protocol PathInspecting: Sendable {
    /// Without following a symlink item.
    func exists(_ url: URL) -> Bool
    func isSymbolicLink(_ url: URL) -> Bool
    func volumeURL(of url: URL) -> URL?
}

nonisolated struct FileSystemPathInspector: PathInspecting {

    // MARK: - Private Static Methods

    /// A trailing slash would make the lookup follow a symlink instead of describing the link.
    private static func withoutTrailingSlash(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path(percentEncoded: false), directoryHint: .notDirectory)
    }

    // MARK: - Public Methods

    func exists(_ url: URL) -> Bool {
        let path = Self.withoutTrailingSlash(url).path(percentEncoded: false)

        // `attributesOfItem` uses lstat, so a dangling symlink still exists.
        return (try? FileManager().attributesOfItem(atPath: path)) != nil
    }

    func isSymbolicLink(_ url: URL) -> Bool {
        let values = try? Self.withoutTrailingSlash(url).resourceValues(forKeys: [.isSymbolicLinkKey])
        return values?.isSymbolicLink ?? false
    }

    func volumeURL(of url: URL) -> URL? {
        let values = try? Self.withoutTrailingSlash(url).resourceValues(forKeys: [.volumeURLKey])
        return values?.volume
    }

}

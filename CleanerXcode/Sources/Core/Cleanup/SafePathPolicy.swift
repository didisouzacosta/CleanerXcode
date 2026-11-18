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
    private let lexicalAllowedBases: [[String]]
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
        self.lexicalAllowedBases = allowedBases.map(\.standardizedFileURL.pathComponents)
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
    /// no folder between its allowed base and itself may be a symlink either: resolved, the root
    /// must be exactly the resolved base plus the same path, without containing a protected path.
    /// Symlinks above the base (such as `/var`) are fine. Returns the resolved root components.
    @discardableResult
    func validateRoot(_ target: CleanupTarget) throws(CleanupError) -> [String] {
        let lexicalRoot = target.root.standardizedFileURL.pathComponents

        guard roots.contains(where: { $0.standardizedFileURL.pathComponents == lexicalRoot }) else {
            throw .unsafePath
        }

        let resolvedRoot = Self.resolvedComponents(of: target.root)
        let staysUnderABase = zip(lexicalAllowedBases, resolvedAllowedBases).contains { lexicalBase, resolvedBase in
            let suffix = lexicalRoot.dropFirst(lexicalBase.count)
            return lexicalRoot.starts(with: lexicalBase) && resolvedRoot == resolvedBase + suffix
        }

        guard
            !inspector.isSymbolicLink(target.root),
            staysUnderABase,
            !resolvedProtectedPaths.contains(where: { $0.starts(with: resolvedRoot) })
        else { throw .unsupportedRoot }

        return resolvedRoot
    }

    /// Accepts `url` only when it:
    /// - is a strict descendant of the target root, without `.` or `..` components;
    /// - is not excluded by the target nor inside another catalog root;
    /// - is not reached through a symlinked folder that leaves the root;
    /// - exists (an item that cannot be looked up throws the real error, such as
    ///   `.permissionDenied`) and lives on the root's volume.
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

        switch inspector.existence(of: url) {
        case .present:
            break
        case .missing:
            throw .notFound
        case let .unreadable(error):
            throw error
        }

        if !inspector.isSymbolicLink(url) {
            guard let volume = inspector.volumeURL(of: url), volume == inspector.volumeURL(of: target.root) else {
                throw .unsafePath
            }
        }
    }

}

nonisolated protocol PathInspecting: Sendable {
    /// Without following a symlink item.
    func existence(of url: URL) -> PathExistence
    func isSymbolicLink(_ url: URL) -> Bool
    func volumeURL(of url: URL) -> URL?
}

nonisolated enum PathExistence: Sendable, Hashable {
    case present
    case missing
    case unreadable(CleanupError)
}

nonisolated struct FileSystemPathInspector: PathInspecting {

    // MARK: - Private Static Methods

    /// A trailing slash would make the lookup follow a symlink instead of describing the link.
    private static func withoutTrailingSlash(_ url: URL) -> URL {
        URL(filePath: url.standardizedFileURL.path(percentEncoded: false), directoryHint: .notDirectory)
    }

    private static func isMissingItemError(_ error: NSError) -> Bool {
        let posixError = error.domain == NSPOSIXErrorDomain ? error : error.userInfo[NSUnderlyingErrorKey] as? NSError

        if let posixError, posixError.domain == NSPOSIXErrorDomain {
            return [Int(ENOENT), Int(ENOTDIR)].contains(posixError.code)
        }

        return error.domain == NSCocoaErrorDomain
            && [CocoaError.fileNoSuchFile.rawValue, CocoaError.fileReadNoSuchFile.rawValue].contains(error.code)
    }

    // MARK: - Public Methods

    /// Only `ENOENT` and `ENOTDIR` mean missing. Any other failure, such as a permission error, is
    /// passed on so the remover reports the real error.
    func existence(of url: URL) -> PathExistence {
        let path = Self.withoutTrailingSlash(url).path(percentEncoded: false)

        // `attributesOfItem` uses lstat, so a dangling symlink still exists.
        do {
            _ = try FileManager().attributesOfItem(atPath: path)
            return .present
        } catch {
            return Self.isMissingItemError(error as NSError) ? .missing : .unreadable(CleanupError(error))
        }
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

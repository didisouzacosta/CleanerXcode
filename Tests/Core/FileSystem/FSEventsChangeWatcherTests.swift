//
//  FSEventsChangeWatcherTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import CoreServices
import Foundation
import Testing
@testable import CleanerXcode

/// The FSEvents adapter (C40 · tempo real, R1): the flag mapping, the empty case and one real
/// stream over a folder the test owns, removed when the test ends.
struct FSEventsChangeWatcherTests {

    // MARK: - Private Static Methods

    private static func path(_ path: String, isInside root: String) -> Bool {
        let path = path.hasSuffix("/") ? String(path.dropLast()) : path
        let root = root.lowercased()

        return path.lowercased() == root || path.lowercased().hasPrefix(root + "/")
    }

    // MARK: - Public Methods

    @Test(.timeLimit(.minutes(1)))
    func nothingToWatchEndsAtOnce() async {
        let stream = FSEventsChangeWatcher().changes(under: [], latency: .seconds(1))

        var batches = 0

        for await _ in stream {
            batches += 1
        }

        #expect(batches == 0)
    }

    @Test(arguments: [
        (kFSEventStreamEventFlagNone, FileSystemChange.Kind.changed),
        (kFSEventStreamEventFlagItemCreated, .changed),
        (kFSEventStreamEventFlagRootChanged, .rootChanged),
        (kFSEventStreamEventFlagMustScanSubDirs, .mustRescan),
        (kFSEventStreamEventFlagUserDropped, .mustRescan),
        (kFSEventStreamEventFlagKernelDropped, .mustRescan),
        (kFSEventStreamEventFlagMustScanSubDirs | kFSEventStreamEventFlagRootChanged, .mustRescan),
    ])
    func flagsMapToTheKindOfChange(flags: Int, kind: FileSystemChange.Kind) {
        let change = FSEventsChangeWatcher.change(path: "/x/", flags: FSEventStreamEventFlags(flags))

        #expect(change == FileSystemChange(path: "/x/", kind: kind))
    }

    /// A real stream that does not ignore this process, since the test writes the file itself.
    @Test(.timeLimit(.minutes(1)))
    func aRealStreamReportsAChangeInsideTheWatchedFolder() async throws {
        let fixture = try TemporaryDirectoryFixture()
        let root = try #require(WatchedCategoryRoots.existingDirectory(fixture.url))
        let found = AsyncStream.makeStream(of: Void.self)
        let stream = FSEventsChangeWatcher(ignoresOwnChanges: false).changes(
            under: [root],
            latency: .milliseconds(100)
        )
        let consumer = Task {
            for await batch in stream where batch.contains(where: { Self.path($0.path, isInside: root) }) {
                found.continuation.yield()
            }
        }

        var signals = found.stream.makeAsyncIterator()

        try fixture.makeFile("a/b.txt")
        try fixture.makeFile("c.txt")

        #expect(await signals.next() != nil)

        consumer.cancel()
        await consumer.value
    }

}

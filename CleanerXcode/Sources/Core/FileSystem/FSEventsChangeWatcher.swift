//
//  FSEventsChangeWatcher.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import CoreServices
import Foundation
import Synchronization

/// Watches folders with a single FSEvents stream (C40 · tempo real, R1). It reports changed
/// directories, not files, grouped by the latency, on its own serial utility queue, and ignores
/// the changes this process makes (its cleanups, the Trash and its own measurements).
///
/// The bridge to `AsyncStream` is the only place that holds the system stream, which is not
/// `Sendable`: it lives in a `Mutex`, and it is stopped and released on the same serial queue the
/// callback runs on, so no callback ever runs while it is invalidated. The buffer is unbounded
/// because the system delivers at most one batch per latency and the consumer only records it.
nonisolated struct FSEventsChangeWatcher: FileSystemChangeWatching {

    // MARK: - Public Properties

    /// Off only in the test that writes its own files.
    let ignoresOwnChanges: Bool

    // MARK: - Private Properties

    /// Directories only (no `FileEvents`), grouped by the latency (no `NoDefer`), and a notice when a
    /// root is removed or renamed (`WatchRoot`).
    private var creationFlags: FSEventStreamCreateFlags {
        var flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagWatchRoot)

        if ignoresOwnChanges {
            flags |= FSEventStreamCreateFlags(kFSEventStreamCreateFlagIgnoreSelf)
        }

        return flags
    }

    // MARK: - Initializers

    init(ignoresOwnChanges: Bool = true) {
        self.ignoresOwnChanges = ignoresOwnChanges
    }

    // MARK: - Public Static Methods

    /// Dropped or coalesced events ask for a rescan; a root change asks to watch again.
    static func change(path: String, flags: FSEventStreamEventFlags) -> FileSystemChange {
        let rescanFlags = FSEventStreamEventFlags(
            kFSEventStreamEventFlagMustScanSubDirs
                | kFSEventStreamEventFlagUserDropped
                | kFSEventStreamEventFlagKernelDropped
        )

        if flags & rescanFlags != 0 {
            return FileSystemChange(path: path, kind: .mustRescan)
        }

        if flags & FSEventStreamEventFlags(kFSEventStreamEventFlagRootChanged) != 0 {
            return FileSystemChange(path: path, kind: .rootChanged)
        }

        return FileSystemChange(path: path, kind: .changed)
    }

    // MARK: - Public Methods

    func changes(under directories: [String], latency: Duration) -> AsyncStream<[FileSystemChange]> {
        let (changes, continuation) = AsyncStream.makeStream(of: [FileSystemChange].self)

        guard !directories.isEmpty else {
            continuation.finish()
            return changes
        }

        // The stream retains the sink until it is released, through these C callbacks.
        let sink = ChangeSink(continuation: continuation)

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(sink).toOpaque(),
            retain: { info in
                if let info {
                    _ = Unmanaged<ChangeSink>.fromOpaque(info).retain()
                }

                return info
            },
            release: { info in
                guard let info else { return }

                Unmanaged<ChangeSink>.fromOpaque(info).release()
            },
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, count, paths, flags, _ in
            guard let info else { return }

            let sink = Unmanaged<ChangeSink>.fromOpaque(info).takeUnretainedValue()
            let cPaths = paths.assumingMemoryBound(to: UnsafePointer<CChar>.self)
            let batch = (0..<count).map { index in
                FSEventsChangeWatcher.change(path: String(cString: cPaths[index]), flags: flags[index])
            }

            sink.yield(batch)
        }

        guard
            let stream = FSEventStreamCreate(
                nil,
                callback,
                &context,
                directories as CFArray,
                FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                latency.timeInterval,
                creationFlags
            )
        else {
            continuation.finish()
            return changes
        }

        let queue = DispatchQueue(label: "com.didisouzacosta.CleanerXcode.file-system-changes", qos: .utility)

        FSEventStreamSetDispatchQueue(stream, queue)

        let handle = StreamHandle(stream)

        // On the callback's queue, so the stream is never invalidated during a callback.
        continuation.onTermination = { _ in
            queue.async {
                handle.invalidate()
            }
        }

        if !handle.start() {
            continuation.finish()
        }

        return changes
    }

    // MARK: - Nested Types

    /// What the C callback reaches through the context's `info`.
    nonisolated private final class ChangeSink: Sendable {

        // MARK: - Private Properties

        private let continuation: AsyncStream<[FileSystemChange]>.Continuation

        // MARK: - Initializers

        init(continuation: AsyncStream<[FileSystemChange]>.Continuation) {
            self.continuation = continuation
        }

        // MARK: - Public Methods

        func yield(_ batch: [FileSystemChange]) {
            continuation.yield(batch)
        }

    }

    /// Owns the system stream: started once, and stopped, invalidated and released once.
    nonisolated private final class StreamHandle: Sendable {

        // MARK: - Private Properties

        private let stream: Mutex<FSEventStreamRef?>

        // MARK: - Initializers

        init(_ stream: sending FSEventStreamRef) {
            self.stream = Mutex(stream)
        }

        // MARK: - Public Methods

        func start() -> Bool {
            stream.withLock { stream in
                guard let stream else { return false }

                return FSEventStreamStart(stream)
            }
        }

        func invalidate() {
            stream.withLock { stream in
                guard let current = stream else { return }

                FSEventStreamStop(current)
                FSEventStreamInvalidate(current)
                FSEventStreamRelease(current)
                stream = nil
            }
        }

    }

}

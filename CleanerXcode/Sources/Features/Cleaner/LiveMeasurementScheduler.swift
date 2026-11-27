//
//  LiveMeasurementScheduler.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// Keeps the sizes current while the folders change (C40 · tempo real): it watches the existing
/// roots of the observed categories and measures again only the touched ones, about 5 s after the
/// changes stop and at most once a minute each, following `LiveMeasurementPolicy`. Without
/// changes it costs nothing: no timer runs and the stream only waits.
///
/// `BackgroundMeasurementScheduler` resumes and pauses it. Batches that arrive while the app
/// cleans or deletes simulators are dropped, since those operations measure everything when they
/// end. Both tasks run on the main actor with utility priority and only record and wait; the
/// measurement itself is the view model's own unstructured task, so pausing, or a new batch, never
/// cancels a measurement in progress: it is read-only, and a newer one replaces it by generation.
final class LiveMeasurementScheduler {

    // MARK: - Public Properties

    private(set) var isResumed = false
    /// For tests: the loop that consumes the stream, and the timer of the next measurement.
    private(set) var watchTask: Task<Void, Never>?
    private(set) var timerTask: Task<Void, Never>?
    private(set) var watchedDirectories: [String] = []
    private(set) var pending = PendingCategoryChanges()

    // MARK: - Private Properties

    private let measuring: any LiveMeasuring
    private let watcher: any FileSystemChangeWatching
    private let isBusy: () -> Bool
    private let policy: LiveMeasurementPolicy
    private let existingDirectory: (URL) -> String?
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void

    private var roots: WatchedCategoryRoots?
    /// The firing in progress, by number. `pause()` clears it, so a firing left over from before a
    /// pause (its measurement keeps running, read-only) never holds back the batches after the
    /// resume, never reschedules and never clears their state: only the current firing does.
    private var firing: Int?
    private var firingCount = 0

    // MARK: - Initializers

    init(
        measuring: any LiveMeasuring,
        watcher: any FileSystemChangeWatching,
        isBusy: @escaping () -> Bool,
        policy: LiveMeasurementPolicy = LiveMeasurementPolicy(),
        existingDirectory: @escaping (URL) -> String? = WatchedCategoryRoots.existingDirectory,
        now: @escaping () -> Date = Date.init,
        sleep: ((Duration) async throws -> Void)? = nil
    ) {
        self.measuring = measuring
        self.watcher = watcher
        self.isBusy = isBusy
        self.policy = policy
        self.existingDirectory = existingDirectory
        self.now = now
        self.sleep = sleep ?? { duration in
            try await Task.sleep(for: duration)
        }
    }

    // MARK: - Public Methods

    /// Idempotent; a stream that could not start is opened again on the next call.
    func resume() {
        isResumed = true

        guard watchTask == nil else { return }

        openStream(with: resolveRoots())
    }

    /// Releases the stream and forgets what was pending.
    func pause() {
        isResumed = false
        watchTask?.cancel()
        timerTask?.cancel()
        watchTask = nil
        timerTask = nil
        watchedDirectories = []
        roots = nil
        firing = nil
        pending.removeAll()
    }

    /// The roots may have appeared or gone: the stream opens again over the new ones, keeping what
    /// is pending.
    func rewatchIfNeeded() {
        guard isResumed else { return }

        let resolved = resolveRoots()

        guard resolved.directories != watchedDirectories else {
            roots = resolved
            return
        }

        watchTask?.cancel()
        watchTask = nil
        openStream(with: resolved)
    }

    /// One batch from the stream; internal for tests. It only records, so a measurement in
    /// progress is never interrupted.
    func handle(_ batch: [FileSystemChange]) {
        guard let roots else { return }

        // Even during a cleanup: a removed root has to leave the stream.
        if roots.needsRewatch(batch) {
            rewatchIfNeeded()
        }

        guard !measuring.isModifyingFiles, !isBusy() else {
            dropPending()
            return
        }

        let ids = roots.categories(affectedBy: batch).intersection(LiveMeasurementPolicy.observedCategoryIDs)

        guard !ids.isEmpty else { return }

        pending.record(ids, at: now())

        // The firing reschedules when its measurement ends.
        guard firing == nil else { return }

        scheduleTimer()
    }

    // MARK: - Private Methods

    private func resolveRoots() -> WatchedCategoryRoots {
        WatchedCategoryRoots.resolve(
            categories: measuring.categories,
            observing: LiveMeasurementPolicy.observedCategoryIDs,
            existingDirectory: existingDirectory
        )
    }

    /// Without any existing root there is nothing to watch. A stream that ends by itself (the
    /// system could not start it) is not opened again in a loop.
    private func openStream(with resolved: WatchedCategoryRoots) {
        roots = resolved
        watchedDirectories = resolved.directories

        guard !resolved.directories.isEmpty else { return }

        let changes = watcher.changes(under: resolved.directories, latency: policy.eventLatency)

        watchTask = Task(priority: .utility) { [weak self] in
            for await batch in changes {
                guard let self else { return }

                handle(batch)
            }

            guard !Task.isCancelled, let self else { return }

            watchTask = nil
            watchedDirectories = []
        }
    }

    private func dropPending() {
        pending.removeAll()
        timerTask?.cancel()
        timerTask = nil
    }

    private func scheduleTimer() {
        timerTask?.cancel()
        timerTask = nil

        guard let due = pending.nextDueDate(policy: policy, measurementStarts: measuring.measurementStarts) else {
            return
        }

        startTimer(after: .seconds(max(due.timeIntervalSince(now()), 0)))
    }

    private func startTimer(after wait: Duration) {
        let sleep = sleep

        timerTask = Task(priority: .utility) { [weak self] in
            if wait > .zero {
                do {
                    try await sleep(wait)
                } catch {
                    return
                }
            }

            guard !Task.isCancelled else { return }

            await self?.fireDue()
        }
    }

    /// Measures the due categories together, then waits for the rest.
    private func fireDue() async {
        firingCount += 1

        let token = firingCount

        firing = token

        defer {
            if firing == token {
                firing = nil
            }
        }

        guard !isBusy() else {
            pending.removeAll()
            return
        }

        switch measuring.categoryMeasurementAvailability {
        case .notReady:
            pending.removeAll()

        case .busy:
            guard !pending.isEmpty else { return }

            startTimer(after: policy.busyRetryDelay)
            return

        case .available:
            let due = pending.takeDue(at: now(), policy: policy, measurementStarts: measuring.measurementStarts)

            if !due.isEmpty {
                await measuring.measureCategories(due)
            }
        }

        // A pause during the measurement made this firing stale.
        guard firing == token, isResumed else { return }

        scheduleTimer()
    }

}

//
//  BackgroundMeasurementSchedulerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Observation
import Testing
@testable import CleanerXcode

/// The loop that measures in the background for the menu bar icon (C40): launch, interval, the
/// conditions that skip a tick, start/stop and sleep/wake, and when the live measurement runs
/// (C40 · tempo real, R6). A manual sleeper replaces real time and a fake watcher FSEvents.
@MainActor
struct BackgroundMeasurementSchedulerTests {

    // MARK: - Private Properties

    private let sleeper = ManualSleeper()
    private let now = Date(timeIntervalSince1970: 100_000)
    private let policy = BackgroundMeasurementPolicy()
    private let watcher = FileSystemChangeWatcherFake()
    private let folders = ExistingFolders()
    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let derivedData = "/Users/qa/Library/Developer/Xcode/DerivedData"
    private let archives = "/Users/qa/Library/Developer/Xcode/Archives"

    // MARK: - Public Methods

    @Test(.timeLimit(.minutes(1)))
    func itMeasuresAfterTheLaunchDelayAndThenWaitsAnInterval() async {
        let spy = BackgroundMeasuringSpy(measuredAt: now)
        let scheduler = makeScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()

        #expect(await arrivals.next() == policy.launchDelay)
        #expect(spy.measureCount == 0)

        sleeper.resume()

        #expect(await arrivals.next() == policy.interval)
        #expect(spy.measureCount == 1)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func turnedOffItNeverMeasures() async {
        let spy = BackgroundMeasuringSpy()
        let scheduler = makeScheduler(measuring: spy, isEnabled: false)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()
        sleeper.resume()

        #expect(await arrivals.next() == policy.interval)
        #expect(spy.measureCount == 0)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func underConstraintsOnlyTheLaunchMeasurementRuns() async {
        let spy = BackgroundMeasuringSpy(measuredAt: now.addingTimeInterval(-3_600))
        let scheduler = makeScheduler(measuring: spy, isConstrained: true)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()
        sleeper.resume()
        _ = await arrivals.next()

        #expect(spy.measureCount == 1)

        sleeper.resume()

        #expect(await arrivals.next() == policy.interval)
        #expect(spy.measureCount == 1, "The periodic tick is skipped.")

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func whileSimulatorsAreDeletedItTriesAgainSoon() async {
        let spy = BackgroundMeasuringSpy()
        let scheduler = makeScheduler(measuring: spy, isBusy: true)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()
        sleeper.resume()

        #expect(await arrivals.next() == policy.retryDelay)
        #expect(spy.measureCount == 0)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func aRecentMeasurementPostponesTheLaunchOne() async {
        let spy = BackgroundMeasuringSpy(lastMeasuredAt: now.addingTimeInterval(-600))
        let scheduler = makeScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()
        sleeper.resume()

        #expect(await arrivals.next() == .seconds(1_200))
        #expect(spy.measureCount == 0)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func startingTwiceRunsASingleLoop() async {
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy())

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        scheduler.start()
        _ = await arrivals.next()
        await Task.yield()

        #expect(sleeper.requested == [policy.launchDelay])

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func stoppingEndsTheLoopForGood() async throws {
        let spy = BackgroundMeasuringSpy()
        let scheduler = makeScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()

        let loop = try #require(scheduler.loop)

        scheduler.stop()
        await loop.value
        scheduler.systemDidWake()
        scheduler.start()

        #expect(scheduler.loop == nil)
        #expect(sleeper.requested == [policy.launchDelay])
        #expect(spy.measureCount == 0)
    }

    @Test(.timeLimit(.minutes(1)))
    func sleepEndsTheLoopAndWakeStartsAnotherAfterTheWakeDelay() async throws {
        let spy = BackgroundMeasuringSpy()
        let scheduler = makeScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await arrivals.next()

        let loop = try #require(scheduler.loop)

        scheduler.systemWillSleep()
        await loop.value

        #expect(scheduler.loop == nil)

        scheduler.systemDidWake()

        #expect(await arrivals.next() == policy.wakeDelay)
        #expect(spy.measureCount == 0)

        sleeper.resume()

        #expect(await arrivals.next() == policy.interval)
        #expect(spy.measureCount == 1)

        scheduler.stop()
    }

    @Test
    func wakingBeforeTheStartDoesNothing() {
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy())

        scheduler.systemDidWake()

        #expect(scheduler.loop == nil)
        #expect(sleeper.requested.isEmpty)
    }

    // MARK: - Live Measurement

    @Test(.timeLimit(.minutes(1)))
    func startingTurnedOnResumesTheLiveMeasurement() async {
        let live = makeLive()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live)

        var requests = watcher.requests.stream.makeAsyncIterator()

        scheduler.start()

        #expect(live.isResumed)
        #expect(await requests.next() == [derivedData])

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func turnedOffTheLiveMeasurementWaitsUntilItIsTurnedOn() async {
        let live = makeLive()
        let enabled = Flag()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live, isEnabled: enabled)

        var requests = watcher.requests.stream.makeAsyncIterator()

        scheduler.start()

        #expect(!live.isResumed)
        #expect(watcher.requestedDirectories.isEmpty)

        enabled.isOn = true
        scheduler.conditionsDidChange()

        #expect(live.isResumed)
        #expect(await requests.next() == [derivedData])

        scheduler.stop()
    }

    /// Low Power Mode or a hot Mac pause it; it comes back when they end.
    @Test(.timeLimit(.minutes(1)))
    func constraintsPauseTheLiveMeasurement() async {
        let live = makeLive()
        let constrained = Flag()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live, isConstrained: constrained)

        var terminations = watcher.terminations.stream.makeAsyncIterator()

        scheduler.start()
        constrained.isOn = true
        scheduler.conditionsDidChange()

        #expect(!live.isResumed)
        #expect(await terminations.next() != nil)

        constrained.isOn = false
        scheduler.conditionsDidChange()

        #expect(live.isResumed)
        #expect(watcher.requestedDirectories.count == 2)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func sleepPausesTheLiveMeasurementAndWakeResumesIt() async {
        let live = makeLive()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live)

        var terminations = watcher.terminations.stream.makeAsyncIterator()

        scheduler.start()
        scheduler.systemWillSleep()

        #expect(!live.isResumed)
        #expect(await terminations.next() != nil)

        scheduler.conditionsDidChange()

        #expect(!live.isResumed, "Still asleep.")

        scheduler.systemDidWake()

        #expect(live.isResumed)

        scheduler.stop()
    }

    @Test(.timeLimit(.minutes(1)))
    func stoppingEndsTheLiveMeasurementForGood() async {
        let live = makeLive()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live)

        var terminations = watcher.terminations.stream.makeAsyncIterator()

        scheduler.start()
        scheduler.stop()

        #expect(await terminations.next() != nil)

        scheduler.conditionsDidChange()
        scheduler.systemDidWake()

        #expect(!live.isResumed)
        #expect(watcher.requestedDirectories.count == 1)
    }

    /// Turning the size off in Settings pauses it at once, through Observation.
    @Test(.timeLimit(.minutes(1)))
    func turningTheOptionOffPausesTheLiveMeasurement() async {
        let live = makeLive()
        let setting = ObservableSetting()
        let scheduler = BackgroundMeasurementScheduler(
            measuring: BackgroundMeasuringSpy(),
            policy: policy,
            isEnabled: { setting.isOn },
            isBusy: { false },
            isConstrained: { false },
            now: { [now] in now },
            sleep: { [sleeper] in try await sleeper.sleep(for: $0) },
            live: live
        )

        var terminations = watcher.terminations.stream.makeAsyncIterator()

        scheduler.start()

        #expect(live.isResumed)

        setting.isOn = false

        #expect(await terminations.next() != nil)
        #expect(!live.isResumed)

        scheduler.stop()
    }

    /// A folder created since (the first Archive) is watched after the next complete measurement.
    @Test(.timeLimit(.minutes(1)))
    func aTickThatMeasuresWatchesTheNewRoots() async {
        let live = makeLive()
        let scheduler = makeScheduler(measuring: BackgroundMeasuringSpy(), live: live)

        var requests = watcher.requests.stream.makeAsyncIterator()
        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.start()
        _ = await requests.next()
        _ = await arrivals.next()
        folders.paths.insert(archives)
        sleeper.resume()

        #expect(await requests.next() == [archives, derivedData])

        scheduler.stop()
    }

    private func makeLive() -> LiveMeasurementScheduler {
        let folders = folders

        folders.paths.insert(derivedData)

        return LiveMeasurementScheduler(
            measuring: BackgroundMeasuringSpy(categories: catalog.categories),
            watcher: watcher,
            isBusy: { false },
            existingDirectory: { folders.existingDirectory($0) },
            sleep: { [sleeper] in try await sleeper.sleep(for: $0) }
        )
    }

    private func makeScheduler(
        measuring: BackgroundMeasuringSpy,
        live: LiveMeasurementScheduler,
        isEnabled: Flag? = nil,
        isConstrained: Flag = Flag()
    ) -> BackgroundMeasurementScheduler {
        let now = self.now
        let sleeper = self.sleeper

        return BackgroundMeasurementScheduler(
            measuring: measuring,
            policy: policy,
            isEnabled: { isEnabled?.isOn ?? true },
            isBusy: { false },
            isConstrained: { isConstrained.isOn },
            now: { now },
            sleep: { try await sleeper.sleep(for: $0) },
            live: live
        )
    }

    // MARK: - Private Methods

    private func makeScheduler(
        measuring: BackgroundMeasuringSpy,
        isEnabled: Bool = true,
        isBusy: Bool = false,
        isConstrained: Bool = false
    ) -> BackgroundMeasurementScheduler {
        let now = self.now
        let sleeper = self.sleeper

        return BackgroundMeasurementScheduler(
            measuring: measuring,
            policy: policy,
            isEnabled: { isEnabled },
            isBusy: { isBusy },
            isConstrained: { isConstrained },
            now: { now },
            sleep: { try await sleeper.sleep(for: $0) }
        )
    }

}

/// A Settings option the scheduler reads through Observation.
@Observable
final class ObservableSetting {
    var isOn = true
}

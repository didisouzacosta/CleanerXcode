//
//  LiveMeasurementSchedulerTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The live measurement (C40 · tempo real, R3–R7): it watches the existing roots, waits for the
/// changes to stop, measures the touched categories together and drops what the app itself is
/// changing. A fake watcher replaces FSEvents, a manual sleeper replaces real time and a manual
/// clock gives the dates, so nothing reads the disk nor waits.
@MainActor
struct LiveMeasurementSchedulerTests {

    // MARK: - Private Properties

    private let sleeper = ManualSleeper()
    private let clock = ManualDateClock()
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
    func resumingWatchesTheExistingRootsOnce() async {
        folders.paths = [derivedData, archives]

        let scheduler = makeScheduler(measuring: makeSpy())

        var requests = watcher.requests.stream.makeAsyncIterator()

        scheduler.resume()
        scheduler.resume()

        #expect(await requests.next() == [archives, derivedData])
        #expect(watcher.requestedDirectories.count == 1)
        #expect(scheduler.isResumed)
        #expect(scheduler.watchedDirectories == [archives, derivedData])

        scheduler.pause()
    }

    @Test
    func withoutAnyExistingRootNothingIsWatched() {
        let scheduler = makeScheduler(measuring: makeSpy())

        scheduler.resume()

        #expect(watcher.requestedDirectories.isEmpty)
        #expect(scheduler.watchTask == nil)

        scheduler.pause()
    }

    /// The batch goes through the stream: 5 s after it, the category is measured once.
    @Test(.timeLimit(.minutes(1)))
    func aChangeIsMeasuredAfterTheQuietPeriod() async {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()
        var measurements = spy.categoryMeasurements.stream.makeAsyncIterator()

        watcher.send([change("\(derivedData)/App/Build")])

        #expect(await arrivals.next() == .seconds(5))
        #expect(spy.measuredCategories.isEmpty)

        clock.advance(by: 5)
        sleeper.resume()

        #expect(await measurements.next() == [.removeDerivedData])
        #expect(spy.measuredCategories == [[.removeDerivedData]])

        scheduler.pause()
    }

    @Test(.timeLimit(.minutes(1)))
    func categoriesDueTogetherAreMeasuredInOneCall() async {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()
        var measurements = spy.categoryMeasurements.stream.makeAsyncIterator()

        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()
        clock.advance(by: 2)
        scheduler.handle([change("\(archives)/x")])

        #expect(await arrivals.next() == .seconds(3), "DerivedData is still due first.")

        clock.advance(by: 5)
        sleeper.resume()

        #expect(await measurements.next() == [.removeDerivedData, .removeArchives])

        scheduler.pause()
    }

    /// A build keeps writing: the category is still measured a minute after the first change.
    @Test(.timeLimit(.minutes(1)))
    func continuousChangesAreMeasuredOnceAMinute() async {
        let scheduler = makeResumedScheduler(measuring: makeSpy())

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        for second in stride(from: 0, through: 57, by: 3) {
            scheduler.handle([change("\(derivedData)/x")])

            #expect(await arrivals.next() == (second < 57 ? .seconds(5) : .seconds(3)), "at \(second) s")

            clock.advance(by: 3)
        }

        scheduler.pause()
    }

    @Test(.timeLimit(.minutes(1)))
    func aRecentMeasurementPostponesTheNextOne() async {
        let spy = makeSpy()

        spy.measurementStarts[.removeDerivedData] = clock.now.addingTimeInterval(-10)

        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.handle([change("\(derivedData)/x")])

        #expect(await arrivals.next() == .seconds(50))

        scheduler.pause()
    }

    /// A complete measurement that started after the change already saw it.
    @Test(.timeLimit(.minutes(1)))
    func aCoveredChangeIsNotMeasuredAgain() async throws {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()

        let timer = try #require(scheduler.timerTask)

        spy.measurementStarts[.removeDerivedData] = clock.now.addingTimeInterval(1)
        clock.advance(by: 5)
        sleeper.resume()
        await timer.value

        #expect(spy.measuredCategories.isEmpty)
        #expect(scheduler.pending.isEmpty)
        #expect(scheduler.timerTask == nil)

        scheduler.pause()
    }

    /// Another measurement or a confirmation: it tries again 5 s later.
    @Test(.timeLimit(.minutes(1)))
    func whileBusyItTriesAgainSoon() async {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()
        var measurements = spy.categoryMeasurements.stream.makeAsyncIterator()

        spy.categoryMeasurementAvailability = .busy
        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()
        clock.advance(by: 5)
        sleeper.resume()

        #expect(await arrivals.next() == LiveMeasurementPolicy().busyRetryDelay)
        #expect(spy.measuredCategories.isEmpty)

        spy.categoryMeasurementAvailability = .available
        clock.advance(by: 5)
        sleeper.resume()

        #expect(await measurements.next() == [.removeDerivedData])

        scheduler.pause()
    }

    /// Before the first complete measurement, or while cleaning: the complete one covers it.
    @Test(.timeLimit(.minutes(1)))
    func whenNotReadyThePendingChangesAreDropped() async throws {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        spy.categoryMeasurementAvailability = .notReady
        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()

        let timer = try #require(scheduler.timerTask)

        clock.advance(by: 5)
        sleeper.resume()
        await timer.value

        #expect(spy.measuredCategories.isEmpty)
        #expect(scheduler.pending.isEmpty)
        #expect(scheduler.timerTask == nil)

        scheduler.pause()
    }

    /// The app's own cleanup or a simulator deletion: their own measurement covers everything.
    @Test(.timeLimit(.minutes(1)), arguments: [true, false])
    func changesWhileTheAppModifiesTheFoldersAreDropped(isCleaning: Bool) async {
        let spy = makeSpy()
        let busy = Flag()
        let scheduler = makeResumedScheduler(measuring: spy, isBusy: busy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()

        if isCleaning {
            spy.isModifyingFiles = true
        } else {
            busy.isOn = true
        }

        scheduler.handle([change("\(archives)/x")])

        #expect(scheduler.pending.isEmpty)
        #expect(scheduler.timerTask == nil)

        spy.isModifyingFiles = false
        busy.isOn = false
        scheduler.handle([change("\(derivedData)/x")])

        #expect(await arrivals.next() == .seconds(5))
        #expect(scheduler.pending.ids == [.removeDerivedData])
        #expect(sleeper.requested == [.seconds(5)])

        scheduler.pause()
    }

    @Test
    func foldersOutsideTheObservedCategoriesAreIgnored() {
        let scheduler = makeResumedScheduler(measuring: makeSpy())

        scheduler.handle([
            change("/private/tmp/qa/x"),
            change("/private/var/tmp/qa/x"),
            change("/Users/qa/Library/Developer/Toolchains/x"),
        ])

        #expect(scheduler.pending.isEmpty)
        #expect(scheduler.timerTask == nil)

        scheduler.pause()
    }

    /// A root appeared: the stream opens again over the new roots and keeps what was pending.
    @Test(.timeLimit(.minutes(1)))
    func aRootChangeWatchesAgainAndKeepsThePendingChanges() async {
        let scheduler = makeResumedScheduler(measuring: makeSpy())

        var requests = watcher.requests.stream.makeAsyncIterator()

        _ = await requests.next()
        scheduler.handle([change("\(derivedData)/x")])
        folders.paths.insert(archives)
        scheduler.handle([change(archives, kind: .rootChanged)])

        #expect(await requests.next() == [archives, derivedData])
        #expect(scheduler.pending.ids == [.removeDerivedData, .removeArchives])

        scheduler.pause()
    }

    @Test(.timeLimit(.minutes(1)))
    func pausingReleasesTheStreamAndDropsTheTimer() async throws {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var terminations = watcher.terminations.stream.makeAsyncIterator()

        scheduler.handle([change("\(derivedData)/x")])

        let timer = try #require(scheduler.timerTask)

        scheduler.pause()

        #expect(await terminations.next() != nil)
        #expect(scheduler.pending.isEmpty)
        #expect(!scheduler.isResumed)
        #expect(scheduler.watchedDirectories.isEmpty)

        clock.advance(by: 5)
        sleeper.resume()
        await timer.value

        #expect(spy.measuredCategories.isEmpty)
    }

    /// A batch during a measurement only waits: the measurement is never cancelled, and the next
    /// timer starts when it ends.
    @Test(.timeLimit(.minutes(1)))
    func aChangeDuringAMeasurementWaitsForItToEnd() async {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()
        var measurements = spy.categoryMeasurements.stream.makeAsyncIterator()

        spy.holdsCategoryMeasurements = true
        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()
        clock.advance(by: 5)
        sleeper.resume()
        _ = await measurements.next()
        scheduler.handle([change("\(archives)/x")])

        #expect(sleeper.requested.count == 1, "No timer while measuring.")
        #expect(scheduler.pending.ids == [.removeArchives])

        spy.releaseCategoryMeasurement()

        #expect(await arrivals.next() == .seconds(5))
        #expect(spy.cancelledCategoryMeasurements == 0)

        scheduler.pause()
    }

    /// A pause (a hot Mac, Low Power Mode, sleep) during a measurement, then a resume: the next
    /// change is still measured, and the old firing neither blocks nor reschedules it.
    @Test(.timeLimit(.minutes(1)))
    func pausingDuringAMeasurementNeverStrandsTheNextChanges() async {
        let spy = makeSpy()
        let scheduler = makeResumedScheduler(measuring: spy)

        var arrivals = sleeper.arrivals.stream.makeAsyncIterator()
        var measurements = spy.categoryMeasurements.stream.makeAsyncIterator()

        spy.holdsCategoryMeasurements = true
        scheduler.handle([change("\(derivedData)/x")])
        _ = await arrivals.next()
        clock.advance(by: 5)
        sleeper.resume()
        _ = await measurements.next()
        scheduler.pause()
        scheduler.resume()
        scheduler.handle([change("\(archives)/x")])
        spy.holdsCategoryMeasurements = false
        spy.releaseCategoryMeasurement()

        #expect(await arrivals.next() == .seconds(5))

        clock.advance(by: 5)
        sleeper.resume()

        #expect(await measurements.next() == [.removeArchives])
        #expect(scheduler.pending.isEmpty)

        scheduler.pause()
    }

    @Test(.timeLimit(.minutes(1)))
    func watchingAgainOnlyReopensWhenTheRootsChanged() async {
        let scheduler = makeResumedScheduler(measuring: makeSpy())

        var requests = watcher.requests.stream.makeAsyncIterator()

        _ = await requests.next()
        scheduler.rewatchIfNeeded()

        #expect(watcher.requestedDirectories.count == 1)

        folders.paths.insert(archives)
        scheduler.rewatchIfNeeded()

        #expect(await requests.next() == [archives, derivedData])

        scheduler.pause()
    }

    // MARK: - Private Methods

    private func makeSpy() -> BackgroundMeasuringSpy {
        BackgroundMeasuringSpy(categories: catalog.categories)
    }

    private func makeScheduler(measuring: BackgroundMeasuringSpy, isBusy: Flag = Flag()) -> LiveMeasurementScheduler {
        let clock = clock
        let sleeper = sleeper
        let folders = folders

        return LiveMeasurementScheduler(
            measuring: measuring,
            watcher: watcher,
            isBusy: { isBusy.isOn },
            existingDirectory: { folders.existingDirectory($0) },
            now: { clock.now },
            sleep: { try await sleeper.sleep(for: $0) }
        )
    }

    /// Resumed over DerivedData.
    private func makeResumedScheduler(
        measuring: BackgroundMeasuringSpy,
        isBusy: Flag = Flag()
    ) -> LiveMeasurementScheduler {
        folders.paths.insert(derivedData)

        let scheduler = makeScheduler(measuring: measuring, isBusy: isBusy)

        scheduler.resume()

        return scheduler
    }

    private func change(_ path: String, kind: FileSystemChange.Kind = .changed) -> FileSystemChange {
        FileSystemChange(path: path, kind: kind)
    }

}

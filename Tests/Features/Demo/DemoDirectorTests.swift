//
//  DemoDirectorTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Testing
@testable import CleanerXcode

struct DemoDirectorTests {

    // MARK: - Public Methods

    @Test
    func runsEveryStepInOrder() async {
        let driver = DemoDriverSpy()
        let sleeper = SleepRecorder()
        let director = DemoDirector(
            steps: [
                .show(.overview),
                .refresh,
                .wait(.seconds(2)),
                .toggle(.removeArchives),
                .requestClean,
                .confirm,
                .dismissReport,
            ],
            sleep: sleeper.sleep
        )

        await director.run(on: driver)

        #expect(driver.calls == [
            "show overview",
            "refresh",
            "toggle removeArchives",
            "requestClean",
            "confirm",
            "dismissReport",
        ])
        #expect(sleeper.durations == [.seconds(2)])
    }

    @Test
    func stopsWhenTheWaitIsCancelled() async {
        let driver = DemoDriverSpy()
        let director = DemoDirector(steps: [.show(.xcode), .wait(.seconds(1)), .show(.overview)]) { _ in
            throw CancellationError()
        }

        await director.run(on: driver)

        #expect(driver.calls == ["show xcode"])
    }

    @Test
    func tourStartsMeasuringOnTheOverviewAndEndsThere() {
        let tour = DemoScript.tour

        #expect(Array(tour.prefix(2)) == [.show(.overview), .refresh])
        #expect(tour.last {
            if case .show = $0 {
                true
            } else {
                false
            }
        } == .show(.overview))
    }

    @Test
    func tourCleansAfterAskingAndShowsTheSimulators() throws {
        let tour = DemoScript.tour
        let request = try #require(tour.firstIndex(of: .requestClean))
        let confirm = try #require(tour.firstIndex(of: .confirm))

        #expect(request < confirm)
        #expect(tour.contains(.toggle(.removeArchives)))
        #expect(tour.contains(.show(.simulatorsAndRuntimes)))
    }

    @Test
    func tourTogglesArchivesOnThePageThatListsIt() throws {
        let tour = DemoScript.tour
        let toggle = try #require(tour.firstIndex(of: .toggle(.removeArchives)))
        let pageShown = tour[..<toggle].last {
            if case .show = $0 {
                true
            } else {
                false
            }
        }

        #expect(pageShown == .show(.userData))
        #expect(CleanerSection.userData.categoryIDs.contains(.removeArchives))
    }

    @Test
    func tourWaitsAboutHalfAMinute() {
        let waited = DemoScript.tour.reduce(Duration.zero) { total, step in
            if case let .wait(duration) = step {
                total + duration
            } else {
                total
            }
        }

        #expect(waited >= .seconds(25))
        #expect(waited <= .seconds(40))
    }

}

private final class DemoDriverSpy: DemoDriving {

    // MARK: - Public Properties

    private(set) var calls: [String] = []

    // MARK: - Public Methods

    func refresh() {
        calls.append("refresh")
    }

    func show(_ destination: SidebarDestination) {
        calls.append("show \(destination.rawValue)")
    }

    func toggle(_ id: CleanupCategoryID) {
        calls.append("toggle \(String(describing: id))")
    }

    func requestClean() {
        calls.append("requestClean")
    }

    func confirm() {
        calls.append("confirm")
    }

    func dismissReport() {
        calls.append("dismissReport")
    }

}

private final class SleepRecorder {

    // MARK: - Public Properties

    private(set) var durations: [Duration] = []

    // MARK: - Public Methods

    func sleep(_ duration: Duration) throws {
        durations.append(duration)
    }

}

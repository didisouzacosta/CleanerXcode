//
//  WorkspaceRunningApplicationsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Uses fake applications only: no real Xcode or Simulator is ever asked to quit.
@MainActor
struct WorkspaceRunningApplicationsTests {

    // MARK: - Public Methods

    @Test
    func reportsXcodeAndSimulatorByTheirBundleIdentifiers() {
        let none = WorkspaceRunningApplications(applications: { _ in [] })
        let both = WorkspaceRunningApplications(applications: { _ in [FakeApplication()] })
        let xcodeOnly = WorkspaceRunningApplications(applications: { bundleID in
            bundleID == "com.apple.dt.Xcode" ? [FakeApplication()] : []
        })

        #expect(!none.isXcodeRunning && !none.isSimulatorRunning)
        #expect(both.isXcodeRunning && both.isSimulatorRunning)
        #expect(xcodeOnly.isXcodeRunning && !xcodeOnly.isSimulatorRunning)
    }

    @Test
    func quittingASimulatorThatIsNotRunningSucceeds() async {
        let applications = WorkspaceRunningApplications(applications: { _ in [] })

        #expect(await applications.terminateSimulator())
    }

    @Test
    func asksEverySimulatorToQuitAndWaitsUntilTheyHaveQuit() async {
        let first = FakeApplication(pollsUntilTerminated: 2)
        let second = FakeApplication(pollsUntilTerminated: 0)
        let applications = makeApplications(simulators: [first, second])

        let didQuit = await applications.terminateSimulator()

        #expect(didQuit)
        #expect(first.terminateCount == 1 && second.terminateCount == 1)
        #expect(first.isTerminated && second.isTerminated)
    }

    /// `terminate()` also returns `false` for an instance that has just quit.
    @Test
    func anInstanceThatAlreadyQuitCountsAsQuit() async {
        let alreadyGone = FakeApplication(acceptsTermination: false, isAlreadyTerminated: true)

        #expect(await makeApplications(simulators: [alreadyGone]).terminateSimulator())
    }

    @Test
    func reportsFailureWhenASimulatorRefusesOrDoesNotQuitInTime() async {
        let refusing = FakeApplication(acceptsTermination: false)
        let stuck = FakeApplication(pollsUntilTerminated: .max)

        #expect(await makeApplications(simulators: [refusing], timeout: .milliseconds(100))
            .terminateSimulator() == false)
        #expect(await makeApplications(simulators: [stuck], timeout: .milliseconds(100)).terminateSimulator() == false)
    }

    @Test
    func neverAsksXcodeToQuit() async {
        let xcode = FakeApplication()
        let applications = WorkspaceRunningApplications(
            applications: { bundleID in bundleID == "com.apple.dt.Xcode" ? [xcode] : [] },
            pollInterval: .milliseconds(5),
            timeout: .milliseconds(50)
        )

        _ = await applications.terminateSimulator()

        #expect(xcode.terminateCount == 0)
        #expect(WorkspaceRunningApplications.simulatorBundleIdentifier == "com.apple.iphonesimulator")
    }

    // MARK: - Private Methods

    /// Success cases get a long deadline so a busy main actor never fails them; only the cases
    /// that must time out use a short one.
    private func makeApplications(
        simulators: [FakeApplication],
        timeout: Duration = .seconds(5)
    ) -> WorkspaceRunningApplications {
        WorkspaceRunningApplications(
            applications: { bundleID in bundleID == "com.apple.iphonesimulator" ? simulators : [] },
            pollInterval: .milliseconds(5),
            timeout: timeout
        )
    }

    // MARK: - Nested Types

    /// Counts the polls through `isTerminated` and quits after the given number of them.
    private final class FakeApplication: TerminatableApplication {

        // MARK: - Public Properties

        private(set) var terminateCount = 0

        var isTerminated: Bool {
            guard !isAlreadyTerminated else { return true }

            guard terminateCount > 0, acceptsTermination else { return false }

            guard remainingPolls > 0 else { return true }

            remainingPolls -= 1
            return false
        }

        // MARK: - Private Properties

        private let acceptsTermination: Bool
        private let isAlreadyTerminated: Bool

        private var remainingPolls: Int

        // MARK: - Initializers

        init(acceptsTermination: Bool = true, pollsUntilTerminated: Int = 0, isAlreadyTerminated: Bool = false) {
            self.acceptsTermination = acceptsTermination
            self.isAlreadyTerminated = isAlreadyTerminated
            self.remainingPolls = pollsUntilTerminated
        }

        // MARK: - Public Methods

        func terminate() -> Bool {
            terminateCount += 1
            return acceptsTermination
        }

    }

}

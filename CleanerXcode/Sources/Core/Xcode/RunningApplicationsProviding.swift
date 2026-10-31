//
//  RunningApplicationsProviding.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit

protocol RunningApplicationsProviding {
    var isXcodeRunning: Bool { get }
    var isSimulatorRunning: Bool { get }
    /// Asks Simulator.app to quit and waits for it; `false` when it did not quit in time (including a
    /// refusal) or the wait was cancelled.
    func terminateSimulator() async -> Bool
}

/// The part of `NSRunningApplication` the app uses, so tests never quit a real application.
protocol TerminatableApplication: AnyObject {
    var isTerminated: Bool { get }

    func terminate() -> Bool
}

extension NSRunningApplication: TerminatableApplication {}

/// Xcode is only ever detected, never asked to quit.
struct WorkspaceRunningApplications: RunningApplicationsProviding {

    // MARK: - Public Properties

    static let xcodeBundleIdentifier = "com.apple.dt.Xcode"
    static let simulatorBundleIdentifier = "com.apple.iphonesimulator"

    var isXcodeRunning: Bool {
        !applications(Self.xcodeBundleIdentifier).isEmpty
    }

    var isSimulatorRunning: Bool {
        !applications(Self.simulatorBundleIdentifier).isEmpty
    }

    // MARK: - Private Properties

    private let applications: (String) -> [any TerminatableApplication]
    private let pollInterval: Duration
    private let timeout: Duration

    // MARK: - Initializers

    init(
        applications: @escaping (String) -> [any TerminatableApplication] = {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0)
        },
        pollInterval: Duration = .milliseconds(100),
        timeout: Duration = .seconds(5)
    ) {
        self.applications = applications
        self.pollInterval = pollInterval
        self.timeout = timeout
    }

    // MARK: - Public Methods

    /// The result of `terminate()` is ignored: it is also `false` for an instance that has just
    /// quit, so only `isTerminated` decides, and a real refusal shows up as the deadline passing.
    /// Polling is bounded and simple, and each suspension of the main actor lets the run loop
    /// refresh `isTerminated`, which `NSRunningApplication` only updates between run loop turns.
    func terminateSimulator() async -> Bool {
        let simulators = applications(Self.simulatorBundleIdentifier)

        guard !simulators.isEmpty else { return true }

        for simulator in simulators where !simulator.isTerminated {
            _ = simulator.terminate()
        }

        let clock = ContinuousClock()
        let deadline = clock.now + timeout

        while !simulators.allSatisfy(\.isTerminated) {
            guard clock.now < deadline else { return false }

            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                return false
            }
        }

        return true
    }

}

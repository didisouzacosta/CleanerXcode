//
//  BackgroundMeasurementScheduler.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Observation

/// Keeps the menu bar icon's size fresh without the window (C40): it measures after the launch
/// delay and then every interval, following `BackgroundMeasurementPolicy`. The loop is a task on
/// the main actor with utility priority that only suspends while it waits; the system's sleep
/// cancels it and the wake starts a new one, since the continuous clock counts the time asleep.
///
/// It also owns the live measurement's lifecycle (C40 · tempo real, R6): the FSEvents stream only
/// runs after `start()`, with the Mac awake, the option on and no Low Power Mode nor hot Mac.
final class BackgroundMeasurementScheduler {

    // MARK: - Public Properties

    /// The live measurement; `nil` in tests that only check the loop.
    let live: LiveMeasurementScheduler?

    /// For tests: the running loop.
    private(set) var loop: Task<Void, Never>?

    // MARK: - Private Properties

    private let measuring: any BackgroundMeasuring
    private let policy: BackgroundMeasurementPolicy
    private let isEnabled: () -> Bool
    private let isBusy: () -> Bool
    private let isConstrained: () -> Bool
    private let now: () -> Date
    private let sleep: (Duration) async throws -> Void

    private var hasStarted = false
    private var isStopped = false
    private var isAsleep = false

    // MARK: - Initializers

    init(
        measuring: any BackgroundMeasuring,
        policy: BackgroundMeasurementPolicy = BackgroundMeasurementPolicy(),
        isEnabled: @escaping () -> Bool,
        isBusy: @escaping () -> Bool,
        isConstrained: @escaping () -> Bool = { PowerConditions.current() },
        now: @escaping () -> Date = Date.init,
        sleep: ((Duration) async throws -> Void)? = nil,
        live: LiveMeasurementScheduler? = nil
    ) {
        let tolerance = policy.tolerance

        self.live = live
        self.measuring = measuring
        self.policy = policy
        self.isEnabled = isEnabled
        self.isBusy = isBusy
        self.isConstrained = isConstrained
        self.now = now
        self.sleep = sleep ?? { duration in
            try await Task.sleep(for: duration, tolerance: tolerance)
        }
    }

    // MARK: - Public Methods

    /// Once per app run; ignored after `stop()`.
    func start() {
        guard !hasStarted, !isStopped else { return }

        hasStarted = true
        launch(firstDelay: policy.launchDelay, isLaunch: true)
        observeEnabled()
        updateLive()
    }

    /// The app is quitting: the loop and the live measurement end for good.
    func stop() {
        isStopped = true
        cancelLoop()
        live?.pause()
    }

    func systemWillSleep() {
        isAsleep = true
        cancelLoop()
        live?.pause()
    }

    /// What changed during the sleep is left to the wake measurement; the stream starts at once.
    func systemDidWake() {
        isAsleep = false
        updateLive()

        guard hasStarted, !isStopped, loop == nil else { return }

        launch(firstDelay: policy.wakeDelay, isLaunch: false)
    }

    /// The options, Low Power Mode or the thermal state changed.
    func conditionsDidChange() {
        updateLive()
    }

    // MARK: - Private Methods

    private func cancelLoop() {
        loop?.cancel()
        loop = nil
    }

    private func updateLive() {
        if hasStarted, !isStopped, !isAsleep, isEnabled(), !isConstrained() {
            live?.resume()
        } else {
            live?.pause()
        }
    }

    /// Turning the option off in Settings pauses the stream at once. `onChange` runs before the
    /// change, so the hop to the main actor reads the new value; each change observes again.
    private func observeEnabled() {
        withObservationTracking {
            _ = isEnabled()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, !isStopped else { return }

                conditionsDidChange()
                observeEnabled()
            }
        }
    }

    /// Cancelling the loop during a measurement does not cancel the measurement: it is the view
    /// model's own unstructured task, read-only, and a newer one replaces it by its generation.
    /// The loop leaves on its next turn.
    private func launch(firstDelay: Duration, isLaunch: Bool) {
        loop = Task(priority: .utility) { [weak self] in
            var delay = firstDelay
            var isLaunch = isLaunch

            while !Task.isCancelled {
                guard let sleep = self?.sleep else { return }

                do {
                    try await sleep(delay)
                } catch {
                    return
                }

                guard !Task.isCancelled, let self else { return }

                delay = await tick(isLaunch: isLaunch)
                isLaunch = false
            }
        }
    }

    /// Measures or not, and returns how long to wait for the next turn. Each turn also checks the
    /// live measurement's conditions, in case a notification was missed, and a complete
    /// measurement watches the roots created since.
    private func tick(isLaunch: Bool) async -> Duration {
        updateLive()

        let decision = policy.decision(
            isLaunch: isLaunch,
            isEnabled: isEnabled(),
            isBusy: isBusy(),
            isConstrained: isConstrained(),
            age: BackgroundMeasurementPolicy.age(since: measuring.lastMeasuredAt, now: now())
        )

        switch decision {
        case .measure:
            await measuring.measureInBackground()
            live?.rewatchIfNeeded()
            return policy.interval

        case let .wait(duration):
            return duration
        }
    }

}

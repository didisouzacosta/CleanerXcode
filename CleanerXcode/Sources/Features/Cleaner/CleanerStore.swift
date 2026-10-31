//
//  CleanerStore.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class CleanerStore {

    // MARK: - Public Variables

    private(set) var usedSpace = StateValue(UsedSpace())
    private(set) var status: CleanerStore.Status = .idle

    var progress: Double {
        steps.count.toDouble()
    }

    var total: CGFloat {
        commands.count.toDouble()
    }

    var freeUpSpace: Double {
        commands.reduce(0) { partial, command in
            partial + size(of: command)
        }.toDouble()
    }

    // MARK: - Private Variables

    private let commandExecutor: CommandExecutor
    private let preferences: Preferences
    private let analytics: Analytics
    private let errorReporter: any ErrorReporting

    private var steps = [CleanerStep]()
    private var timer: Timer?
    private var calculateFreeUpSpaceTask: Task<Void, Error>?
    private var cleanerTask: Task<Void, Error>?

    private var commands: [Command] {
        [
            preferences.removeArchives,
            preferences.removeCaches,
            preferences.removeDerivedData,
            preferences.removeOldSimulators,
            preferences.clearDeviceSupport,
            preferences.clearSimulatorData,
            preferences.resetXcodePreferences,
        ]
        .filter { $0.value }
        .compactMap { $0.toCommand() }
    }

    private var errors: [Error] {
        steps.compactMap { $0.error }
    }

    // MARK: - Initializers

    init(
        commandExecutor: CommandExecutor,
        preferences: Preferences,
        analytics: Analytics,
        errorReporter: any ErrorReporting
    ) {
        self.commandExecutor = commandExecutor
        self.preferences = preferences
        self.analytics = analytics
        self.errorReporter = errorReporter

        calculateFreeUpSpace()
    }

    // MARK: - Public Methods

    func clear() {
        status = .isCleaning
        steps = []

        stopTimer()

        cleanerTask?.cancel()
        cleanerTask = Task {
            guard !Task.isCancelled else { return }

            let cleanupCommands = commands
            let estimatedFreedBytes = Int64(freeUpSpace * 1024)

            errorReporter.breadcrumb(.cleanupStarted)

            for command in cleanupCommands {
                if Task.isCancelled {
                    break
                }

                let step: CleanerStep

                do {
                    try await commandExecutor.run(command)
                    calculateFreeUpSpace()
                    step = CleanerStep(command)
                } catch {
                    step = CleanerStep(command, error: error)
                }

                try? await Task.sleep(nanoseconds: 0.5.second)
                steps.append(step)
            }

            errorReporter.breadcrumb(.cleanupFinished)
            logCleanup(commands: cleanupCommands, estimatedFreedBytes: estimatedFreedBytes)
            calculateFreeUpSpace()

            try? await Task.sleep(nanoseconds: 1.second)

            steps = steps.filter { $0.hasError }
            status = .isCompleted

            try? await Task.sleep(nanoseconds: 2.second)

            status = .idle

            await Task.yield()
        }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Private Methods

    /// Logs the analytics events and, when something failed, a single aggregated error report.
    /// `freedBytes` is the estimate measured before the cleanup; the real freed amount arrives with card C17.
    private func logCleanup(commands: [Command], estimatedFreedBytes: Int64) {
        let failedCategories = steps.filter(\.hasError).map(\.command.script)
        let result: AnalyticsEvent.CleanupResultKind = switch failedCategories.count {
        case 0: .success
        case steps.count: .failure
        default: .partialFailure
        }

        analytics.log(
            .cleaner(
                categories: commands.map(\.script),
                result: result,
                freedBytes: estimatedFreedBytes
            )
        )

        if !failedCategories.isEmpty {
            analytics.log(.cleanerPartialFailure(failedCategories: failedCategories, errorKinds: [.other]))
            errorReporter.capture(
                .cleanupFailed(failedCategories: failedCategories, errorKinds: [.other], totalCategories: steps.count)
            )
        }
    }

    private func startTimer() {
        let timer = Timer(
            fire: .now.addingTimeInterval(6),
            interval: 0,
            repeats: false
        ) { [weak self] _ in
            // The timer is scheduled on RunLoop.main, so it always fires on the main actor.
            MainActor.assumeIsolated {
                self?.calculateFreeUpSpace()
            }
        }

        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func stopTimer() {
        calculateFreeUpSpaceTask?.cancel()
        timer?.invalidate()
        timer = nil
    }

    private func calculateFreeUpSpace() {
        usedSpace.isLoading = true

        stopTimer()

        calculateFreeUpSpaceTask?.cancel()
        calculateFreeUpSpaceTask = Task { @MainActor in
            guard !Task.isCancelled else { return }

            usedSpace.value = await (try? commandExecutor.runDecoder(.calculateFreeUpSpace)) ?? .init()
            await Task.yield()
            startTimer()
        }
    }

}

extension CleanerStore {

    // MARK: - Private Methods

    private func size(of command: Command) -> Int {
        switch command {
        case .removeArchives:
            usedSpace.value.archives
        case .removeCaches:
            usedSpace.value.cache
        case .removeDerivedData:
            usedSpace.value.derivedData
        case .clearDeviceSupport:
            usedSpace.value.deviceSupport
        case .clearSimulatorData:
            usedSpace.value.simulatorData
        default: 0
        }
    }

    // MARK: - Nested Types

    enum Status: Equatable {
        case idle
        case isCompleted
        case isCleaning
        case error
    }

}

private struct CleanerStep: Equatable, Identifiable {

    // MARK: - Public Variables

    let command: Command
    let error: Error?

    var id: String {
        command.id
    }

    var hasError: Bool {
        error != nil
    }

    // MARK: - Initializers

    init(_ command: Command, error: Error? = nil) {
        self.command = command
        self.error = error
    }

    // MARK: - Public Methods

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }

}

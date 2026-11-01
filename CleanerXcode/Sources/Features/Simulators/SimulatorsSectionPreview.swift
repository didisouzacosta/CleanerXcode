//
//  SimulatorsSectionPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import SwiftUI

    /// Drives a real `SimulatorsViewModel` with an in-memory service into each state of the
    /// section; nothing runs `simctl`.
    struct SimulatorsSectionPreview: View {

        // MARK: - States

        @State private var viewModel: SimulatorsViewModel

        // MARK: - Public Properties

        var body: some View {
            ScrollView {
                SimulatorsSectionView(
                    viewModel: viewModel,
                    isLocked: false,
                    isInitiallyCollapsed: false,
                    isListInitiallyExpanded: true
                )
                .padding(16)
            }
            .frame(width: 560, height: 720)
            .task {
                await Self.prepare(viewModel, for: scenario)
            }
        }

        // MARK: - Private Properties

        private let scenario: Scenario

        // MARK: - Initializers

        init(_ scenario: Scenario) {
            self.scenario = scenario
            _viewModel = State(initialValue: Self.makeViewModel(for: scenario))
        }

        // MARK: - Public Methods

        static func makeViewModel(for scenario: Scenario) -> SimulatorsViewModel {
            SimulatorsViewModel(simulators: PreviewSimulatorsService(scenario: scenario), analytics: NullAnalytics())
        }

        /// Brings the view model to the scenario's phase. The section also loads when it expands,
        /// which can supersede this load, so each step waits for the list first.
        static func prepare(_ viewModel: SimulatorsViewModel, for scenario: Scenario) async {
            await viewModel.load()
            await waitUntilListed(viewModel)

            switch scenario {
            case .deleting:
                viewModel.selectDuplicates()
                viewModel.requestDeleteSelected()

                Task { await viewModel.confirm() }

            case .deleteFailed:
                viewModel.selectDuplicates()
                viewModel.requestDeleteSelected()
                await viewModel.confirm()

            case .confirmingDevices:
                viewModel.selectDuplicates()
                viewModel.requestDeleteSelected()

            case .confirmingRuntime:
                if let runtime = viewModel.runtimes.first(where: \.isDeletable) {
                    viewModel.requestDeleteRuntime(runtime)
                }

            default:
                break
            }
        }

        // MARK: - Private Methods

        private static func waitUntilListed(_ viewModel: SimulatorsViewModel) async {
            while viewModel.phase == .idle || viewModel.phase == .loading, !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        // MARK: - Nested Types

        enum Scenario {

            // MARK: - Cases

            case loaded
            case loading
            case empty
            case toolsUnavailable
            case failed
            case deleting
            case deleteFailed
            case unusualStates
            case confirmingDevices
            case confirmingRuntime
        }

    }

    /// The confirmation sheet on its own, prepared by the same fakes.
    struct SimulatorsConfirmationPreview: View {

        // MARK: - States

        @State private var viewModel: SimulatorsViewModel

        // MARK: - Public Properties

        var body: some View {
            ZStack {
                Color.clear

                if let confirmation = viewModel.confirmation {
                    SimulatorsConfirmationSheet(confirmation: confirmation, viewModel: viewModel)
                }
            }
            .frame(width: 420, height: 320)
            .task {
                await SimulatorsSectionPreview.prepare(viewModel, for: scenario)
            }
        }

        // MARK: - Private Properties

        private let scenario: SimulatorsSectionPreview.Scenario

        // MARK: - Initializers

        init(_ scenario: SimulatorsSectionPreview.Scenario) {
            self.scenario = scenario
            _viewModel = State(initialValue: SimulatorsSectionPreview.makeViewModel(for: scenario))
        }

    }

    /// Devices and runtimes close to the Figma frame "Simuladores e runtimes".
    nonisolated private struct PreviewSimulatorsService: SimulatorManaging {

        // MARK: - Private Properties

        private static let iOS272 = "com.apple.CoreSimulator.SimRuntime.iOS-27-2"
        private static let iOS271 = "com.apple.CoreSimulator.SimRuntime.iOS-27-1"
        private static let watchOS271 = "com.apple.CoreSimulator.SimRuntime.watchOS-27-1"

        private let scenario: SimulatorsSectionPreview.Scenario

        // MARK: - Initializers

        init(scenario: SimulatorsSectionPreview.Scenario) {
            self.scenario = scenario
        }

        // MARK: - Public Methods

        func listDevices(in set: DeviceSet) async throws -> [SimulatorDevice] {
            switch scenario {
            case .loading:
                try await Task.sleep(for: .seconds(3_600))
                return []

            case .empty:
                return []

            case .toolsUnavailable:
                throw CleanupError.toolUnavailable

            case .failed:
                throw CleanupError.timedOut

            case .unusualStates:
                return [
                    device("1", "iPhone 17 Pro", Self.iOS272, daysAgo: 2, bytes: 2_400_000_000),
                    device("2", "QA phone", Self.iOS271, daysAgo: 9, bytes: 900_000_000, isAvailable: false),
                ]

            default:
                return [
                    device("1", "iPhone 17 Pro", Self.iOS272, daysAgo: 2, bytes: 2_400_000_000),
                    device("2", "iPhone 17 Pro", Self.iOS272, daysAgo: 38, bytes: 2_900_000_000),
                    device("3", "iPad Pro 13\"", Self.iOS272, daysAgo: 0, bytes: 3_300_000_000),
                    device("4", "iPhone Air", Self.iOS271, daysAgo: nil, bytes: 218_000_000),
                    device("5", "iPhone Air", Self.iOS271, daysAgo: 3, bytes: 1_100_000_000),
                    device("6", "Apple Watch Ultra 3", Self.watchOS271, daysAgo: 12, bytes: 1_600_000_000),
                ]
            }
        }

        func listRuntimes() throws -> [SimulatorRuntime] {
            if case .empty = scenario {
                return []
            }

            if case .unusualStates = scenario {
                return [
                    runtime(
                        "R1",
                        Self.iOS271,
                        build: "24A94425",
                        bytes: 7_600_000_000,
                        deletable: true,
                        state: "Unusable"
                    ),
                    runtime(
                        "R3",
                        Self.watchOS271,
                        build: "24R382",
                        bytes: 3_100_000_000,
                        deletable: true,
                        state: "Deleting"
                    ),
                ]
            }

            return [
                runtime("R2", Self.iOS272, build: "24B114", bytes: 7_500_000_000, deletable: false),
                runtime("R1", Self.iOS271, build: "24A94425", bytes: 7_600_000_000, deletable: true),
            ]
        }

        func delete(_ devices: [SimulatorDevice], in set: DeviceSet) async throws {
            if case .deleteFailed = scenario {
                throw CleanupError.inUse
            }

            try await Task.sleep(for: .seconds(3_600))
        }

        func deleteRuntime(identifier: String) async throws {
            try await Task.sleep(for: .seconds(3_600))
        }

        func shutdownAll(in set: DeviceSet) throws {}

        func deleteUnavailable() throws {}

        func eraseAll() throws {}

        func deleteAllDevices(in set: DeviceSet) throws {}

        func restartService() throws {}

        // MARK: - Private Methods

        private func device(
            _ udid: String,
            _ name: String,
            _ runtime: String,
            daysAgo: Double?,
            bytes: Int64,
            isAvailable: Bool = true
        ) -> SimulatorDevice {
            SimulatorDevice(
                udid: udid,
                name: name,
                deviceTypeIdentifier: "com.apple.CoreSimulator.SimDeviceType."
                    + name.replacing("\"", with: "").replacing(" ", with: "-"),
                runtimeIdentifier: runtime,
                state: daysAgo == 0 ? .booted : .shutdown,
                isAvailable: isAvailable,
                lastUsedAt: daysAgo.map { Date.now.addingTimeInterval(-$0 * 86_400) },
                sizeBytes: bytes
            )
        }

        private func runtime(
            _ identifier: String,
            _ runtimeIdentifier: String,
            build: String,
            bytes: Int64,
            deletable: Bool,
            state: String = "Ready"
        ) -> SimulatorRuntime {
            SimulatorRuntime(
                identifier: identifier,
                runtimeIdentifier: runtimeIdentifier,
                version: "27",
                build: build,
                platformIdentifier: "com.apple.platform.iphonesimulator",
                sizeBytes: bytes,
                lastUsedAt: deletable ? Date.now.addingTimeInterval(-61 * 86_400) : nil,
                isDeletable: deletable,
                state: state,
                kind: deletable ? "Patchable Cryptex Disk Image" : "Bundled with Xcode"
            )
        }

    }
#endif

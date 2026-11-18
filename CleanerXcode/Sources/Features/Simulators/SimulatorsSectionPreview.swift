//
//  SimulatorsSectionPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import SwiftUI

    /// Drives a real `SimulatorsViewModel` with an in-memory service into each state of the
    /// "Simulators and runtimes" page; nothing runs `simctl` nor `xcodebuild`.
    struct SimulatorsSectionPreview: View {

        // MARK: - States

        @State private var viewModel: SimulatorsViewModel

        // MARK: - Public Properties

        var body: some View {
            ScrollView {
                SimulatorsPageView(viewModel: viewModel, isLocked: isLocked)
                    .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .frame(width: 668, height: 620)
            .background(Palette.window)
            .task {
                await Self.prepare(viewModel, for: scenario)
            }
        }

        // MARK: - Private Properties

        private let scenario: Scenario
        private let isLocked: Bool

        // MARK: - Initializers

        init(_ scenario: Scenario, isLocked: Bool = false) {
            self.scenario = scenario
            self.isLocked = isLocked
            _viewModel = State(initialValue: Self.makeViewModel(for: scenario))
        }

        // MARK: - Public Methods

        /// The versions of the "Download runtimes" sheet come from `versionSource` (C35).
        static func makeViewModel(
            for scenario: Scenario,
            versionSource: PreviewRuntimeVersionSource = PreviewRuntimeVersionSource(.loaded)
        ) -> SimulatorsViewModel {
            SimulatorsViewModel(
                simulators: PreviewSimulatorsService(scenario: scenario),
                downloader: downloader(for: scenario),
                versionSource: versionSource,
                analytics: NullAnalytics(),
                now: PreviewClock().tick
            )
        }

        /// Brings the view model to the scenario's phase. The page also loads when it appears,
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

            case .downloading, .downloadQueue, .downloadProgress, .downloadTimeLeft, .downloadLongTimeLeft,
                 .downloadInstalling, .downloadQueueProgress:
                Task { await download(downloadSelection(for: scenario), in: viewModel) }

            case .downloadInstalled, .downloadAllInstalled, .downloadFailed, .downloadPartlyFailed:
                await download(downloadSelection(for: scenario), in: viewModel)

            case .downloadCancelled, .downloadCancelledAfterInstalling:
                let selection = downloadSelection(for: scenario)

                Task { await download(selection, in: viewModel) }

                await waitUntilDownloading(selection.last, in: viewModel)
                viewModel.cancelRuntimeDownload()

            default:
                break
            }
        }

        // MARK: - Private Methods

        /// Only the scenario's own platforms finish or fail; the one shown in progress waits.
        private static func downloader(for scenario: Scenario) -> PreviewRuntimeDownloader {
            if let downloader = progressDownloader(for: scenario) {
                return downloader
            }

            return switch scenario {
            case .downloadQueue: PreviewRuntimeDownloader([.watchOS: .hold])
            case .downloadInstalled, .downloadAllInstalled: PreviewRuntimeDownloader()
            case .downloadFailed: PreviewRuntimeDownloader(default: .fail(.timedOut))
            case .downloadPartlyFailed: PreviewRuntimeDownloader([.visionOS: .fail(.timedOut)])
            case .downloadCancelledAfterInstalling: PreviewRuntimeDownloader([.visionOS: .hold])
            default: PreviewRuntimeDownloader(default: .hold)
            }
        }

        /// The C34 scenarios: the platform in progress reports its steps, then waits.
        private static func progressDownloader(for scenario: Scenario) -> PreviewRuntimeDownloader? {
            typealias Fixtures = RuntimeDownloadPreviewFixtures

            return switch scenario {
            case .downloadProgress: PreviewRuntimeDownloader(default: .progress([Fixtures.threePercentStep]))
            case .downloadTimeLeft: PreviewRuntimeDownloader(default: .progress(Fixtures.fortyTwoPercentSteps))
            case .downloadLongTimeLeft: PreviewRuntimeDownloader(default: .progress(Fixtures.sevenPercentSteps))
            case .downloadInstalling: PreviewRuntimeDownloader(default: .progress([.installing]))
            case .downloadQueueProgress: PreviewRuntimeDownloader([.watchOS: .progress(Fixtures.fortyTwoPercentSteps)])
            default: nil
            }
        }

        private static func downloadSelection(for scenario: Scenario) -> [RuntimePlatform] {
            switch scenario {
            case .downloadQueue, .downloadQueueProgress: [.iOS, .watchOS, .visionOS]
            case .downloadAllInstalled, .downloadPartlyFailed, .downloadCancelledAfterInstalling: [.watchOS, .visionOS]
            default: [.iOS]
            }
        }

        /// Through the sheet, as the page does.
        private static func download(_ platforms: [RuntimePlatform], in viewModel: SimulatorsViewModel) async {
            viewModel.requestRuntimeDownload()

            for platform in platforms {
                viewModel.toggleRuntimePlatform(platform)
            }

            await viewModel.confirmRuntimeDownload()
        }

        /// Until `platform` is the one being downloaded.
        private static func waitUntilDownloading(
            _ platform: RuntimePlatform?,
            in viewModel: SimulatorsViewModel
        ) async {
            while !Task.isCancelled {
                if case let .downloading(run) = viewModel.runtimeDownload, run.current == platform {
                    return
                }

                try? await Task.sleep(for: .milliseconds(20))
            }
        }

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
            case downloading
            case downloadQueue
            case downloadInstalled
            case downloadAllInstalled
            case downloadFailed
            case downloadPartlyFailed
            case downloadCancelled
            case downloadCancelledAfterInstalling
            /// C34: 3% without the time left yet.
            case downloadProgress
            /// C34: 42%, about 12 min left.
            case downloadTimeLeft
            /// C34: 7%, about 1 h 20 min left.
            case downloadLongTimeLeft
            case downloadInstalling
            /// C34: watchOS at 42% (2 of 3), about 12 min left.
            case downloadQueueProgress
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
        private static let iOS273 = "com.apple.CoreSimulator.SimRuntime.iOS-27-3"
        private static let watchOS272 = "com.apple.CoreSimulator.SimRuntime.watchOS-27-2"
        private static let visionOS272 = "com.apple.CoreSimulator.SimRuntime.xrOS-27-2"

        private let scenario: SimulatorsSectionPreview.Scenario

        // MARK: - Initializers

        init(scenario: SimulatorsSectionPreview.Scenario) {
            self.scenario = scenario
        }

        // MARK: - Private Static Methods

        private static func platformIdentifier(of runtimeIdentifier: String) -> String {
            let platform = RuntimePlatform.allCases.first { platform in
                let name = platform == .visionOS ? "xrOS" : platform.rawValue

                return runtimeIdentifier.contains(".SimRuntime.\(name)-")
            }

            return platform?.simulatorPlatformIdentifier ?? ""
        }

        /// `…SimRuntime.iOS-27-2` → `27.2`.
        private static func version(of runtimeIdentifier: String) -> String {
            runtimeIdentifier.split(separator: "-").dropFirst().joined(separator: ".")
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

            let runtimes = [
                runtime("R2", Self.iOS272, build: "24B114", bytes: 7_500_000_000, deletable: false),
                runtime("R1", Self.iOS271, build: "24A94425", bytes: 7_600_000_000, deletable: true),
            ]

            return runtimes + installedByTheDownloads()
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

        /// The runtimes the downloads of the scenario just installed.
        private func installedByTheDownloads() -> [SimulatorRuntime] {
            switch scenario {
            case .downloadInstalled:
                [
                    runtime(
                        "R4",
                        Self.iOS273,
                        build: "24C5089c",
                        bytes: 8_100_000_000,
                        deletable: true,
                        lastUsed: false
                    ),
                ]

            case .downloadAllInstalled:
                [
                    runtime(
                        "R5",
                        Self.watchOS272,
                        build: "24R412",
                        bytes: 3_400_000_000,
                        deletable: true,
                        lastUsed: false
                    ),
                    runtime(
                        "R6",
                        Self.visionOS272,
                        build: "24N310",
                        bytes: 9_200_000_000,
                        deletable: true,
                        lastUsed: false
                    ),
                ]

            default:
                []
            }
        }

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
            state: String = "Ready",
            lastUsed: Bool = true
        ) -> SimulatorRuntime {
            SimulatorRuntime(
                identifier: identifier,
                runtimeIdentifier: runtimeIdentifier,
                version: Self.version(of: runtimeIdentifier),
                build: build,
                platformIdentifier: Self.platformIdentifier(of: runtimeIdentifier),
                sizeBytes: bytes,
                lastUsedAt: deletable && lastUsed ? Date.now.addingTimeInterval(-61 * 86_400) : nil,
                isDeletable: deletable,
                state: state,
                kind: deletable ? "Patchable Cryptex Disk Image" : "Bundled with Xcode"
            )
        }

    }
#endif

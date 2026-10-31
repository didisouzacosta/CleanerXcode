//
//  CleanerWindowPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import SwiftUI

    /// Drives a real `CleanerViewModel` with fakes over `CleanupLocations.inert` into each state of
    /// the Figma page 03, so the previews never read this Mac's folders, run `simctl` or remove
    /// anything.
    struct CleanerWindowPreview: View {

        // MARK: - States

        @State private var viewModel: CleanerViewModel
        @State private var simulators = SimulatorsSectionPreview.makeViewModel(for: .loaded)
        @State private var updates = UpdatePreview.makeViewModel()

        // MARK: - Public Properties

        var body: some View {
            CleanerWindowView(
                viewModel: viewModel,
                simulators: simulators,
                updates: updates,
                versionText: "1.0.0 (115)"
            )
            .environment(\.reducesTransparencyOverride, reducesTransparency ? true : nil)
            .frame(width: 560, height: 720)
            .task {
                await Self.prepare(viewModel, for: scenario)
            }
        }

        // MARK: - Private Properties

        private let scenario: Scenario
        private let reducesTransparency: Bool

        // MARK: - Initializers

        init(_ scenario: Scenario, reducesTransparency: Bool = false) {
            self.scenario = scenario
            self.reducesTransparency = reducesTransparency
            _viewModel = State(initialValue: Self.makeViewModel(for: scenario))
        }

        // MARK: - Public Methods

        static func makeViewModel(for scenario: Scenario) -> CleanerViewModel {
            let catalog = CleanupCatalog(locations: .inert)
            let preferences = PreviewPreferencesStore()

            if case .nothingSelected = scenario {
                catalog.categories.forEach { preferences.setSelected($0.id, false) }
            } else if case .confirming = scenario {
                preferences.setSelected(.removeArchives, true)
            }

            return CleanerViewModel(
                catalog: catalog,
                measurer: CategorySizeMeasurer(scanner: PreviewScanner(scenario: scenario)),
                simulators: scenario == .toolsUnavailable ? InertSimulatorManager() : PreviewSimulatorManager(),
                executor: PreviewExecutor(scenario: scenario),
                preferences: preferences,
                runningApplications: PreviewRunningApplications(scenario: scenario),
                analytics: NullAnalytics(),
                errorReporter: NullErrorReporter(),
                appBundleIdentifier: "didisouzacosta.CleanerXcode"
            )
        }

        /// Brings the view model to the scenario's phase.
        static func prepare(_ viewModel: CleanerViewModel, for scenario: Scenario) async {
            await viewModel.refresh()

            switch scenario {
            case .confirming, .confirmingWhileXcodeIsOpen:
                await viewModel.requestClean()

            case .cleaning, .finished, .permissionDenied:
                // `confirm()` does nothing when the plan ran without a confirmation.
                await viewModel.requestClean()
                await viewModel.confirm()

            case .cancelling:
                await cancelARunningCleanup(viewModel)

            default:
                break
            }
        }

        // MARK: - Private Methods

        private static func cancelARunningCleanup(_ viewModel: CleanerViewModel) async {
            Task {
                await viewModel.requestClean()
                await viewModel.confirm()
            }

            while !Task.isCancelled {
                if case .cleaning = viewModel.phase {
                    viewModel.cancel()
                    return
                }

                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        // MARK: - Nested Types

        enum Scenario: Equatable {

            // MARK: - Cases

            case ready
            case measuring
            case nothingSelected
            case nothingToClean
            case confirming
            case confirmingWhileXcodeIsOpen
            case cleaning
            case cancelling
            case finished(CleanupReport.Outcome)
            case permissionDenied
            case xcodeOpen
            case simulatorOpen
            case toolsUnavailable
        }

    }

    private final class PreviewPreferencesStore: PreferencesStoring {

        // MARK: - Public Properties

        var schemaVersion: Int {
            PreferencesMigrator.currentSchemaVersion
        }

        // MARK: - Private Properties

        private var values: [String: Bool] = [:]
        private var integers: [String: Int] = [:]

        // MARK: - Public Methods

        func storedValue(for key: String) -> StoredBool {
            values[key].map(StoredBool.value) ?? .missing
        }

        func set(_ value: Bool, for key: String) {
            values[key] = value
        }

        func integer(for key: String) -> Int? {
            integers[key]
        }

        func set(_ value: Int, for key: String) {
            integers[key] = value
        }

        func removeValue(for key: String) {
            values[key] = nil
        }

        func setSchemaVersion(_ version: Int) {}

    }

    /// Sizes close to the Figma frames, by the last folder of each target.
    nonisolated private struct PreviewScanner: DiskUsageScanning {

        // MARK: - Private Properties

        private static let sizes: [String: Int64] = [
            "DerivedData": 30_100_000_000,
            "com.apple.dt.Xcode": 1_200_000_000,
            "iOS DeviceSupport": 6_400_000_000,
            "Archives": 4_200_000_000,
            "Products": 12_000_000,
            "Caches": 820_000_000,
        ]

        private let scenario: CleanerWindowPreview.Scenario

        // MARK: - Initializers

        init(scenario: CleanerWindowPreview.Scenario) {
            self.scenario = scenario
        }

        // MARK: - Public Methods

        func allocatedSize(of target: CleanupTarget) async throws -> Int64 {
            switch scenario {
            case .measuring:
                try await Task.sleep(for: .seconds(3_600))
                return 0

            case .nothingToClean:
                return 0

            default:
                return Self.sizes[target.root.lastPathComponent] ?? 0
            }
        }

    }

    nonisolated private struct PreviewSimulatorManager: SimulatorManaging {

        // MARK: - Public Methods

        func listDevices(in set: DeviceSet) throws -> [SimulatorDevice] {
            []
        }

        func listRuntimes() throws -> [SimulatorRuntime] {
            []
        }

        func shutdownAll(in set: DeviceSet) throws {}

        func delete(_ devices: [SimulatorDevice], in set: DeviceSet) throws {}

        func deleteUnavailable() throws {}

        func eraseAll() throws {}

        func deleteAllDevices(in set: DeviceSet) throws {}

        func deleteRuntime(identifier: String) throws {}

        func restartService() throws {}

    }

    private struct PreviewExecutor: CleanupExecuting {

        // MARK: - Public Properties

        let scenario: CleanerWindowPreview.Scenario

        // MARK: - Public Methods

        func execute(_ plan: CleanupPlan, onEvent: @escaping (CleanupEvent) -> Void) async -> CleanupReport {
            switch scenario {
            case .cleaning:
                onEvent(.categoryStarted(.removeDerivedData))
                onEvent(.itemFinished(result(.removeDerivedData, .removed)))
                try? await Task.sleep(for: .seconds(3_600))
                return CleanupReport(results: [])

            case .cancelling:
                onEvent(.categoryStarted(.removeDerivedData))
                // Never returns, even when cancelled, so the preview stays in "Cancelling…". The
                // continuation is never resumed on purpose: it only parks a preview's task.
                await withUnsafeContinuation { (_: UnsafeContinuation<Void, Never>) in }
                return CleanupReport(results: [])

            case let .finished(outcome):
                return report(outcome)

            case .permissionDenied:
                return CleanupReport(results: [result(.removeArchives, .failed(.permissionDenied))])

            default:
                return CleanupReport(results: [])
            }
        }

        // MARK: - Private Methods

        private func report(_ outcome: CleanupReport.Outcome) -> CleanupReport {
            switch outcome {
            case .success:
                CleanupReport(results: [result(.removeDerivedData, .removed), result(.removeArchives, .trashed)])

            case .partialFailure:
                CleanupReport(results: [result(.removeDerivedData, .failed(.inUse)), result(.removeCaches, .removed)])

            case .failure:
                CleanupReport(results: [result(.removeDerivedData, .failed(.inUse))])

            case .cancelled:
                CleanupReport(results: [result(.removeDerivedData, .removed)], wasCancelled: true)
            }
        }

        private func result(_ id: CleanupCategoryID, _ outcome: CleanupItemResult.Outcome) -> CleanupItemResult {
            CleanupItemResult(
                categoryID: id,
                displayPath: "~/Library/Developer/Xcode/\(id.rawValue)",
                bytes: 12_400_000_000,
                outcome: outcome
            )
        }

    }

    private struct PreviewRunningApplications: RunningApplicationsProviding {

        // MARK: - Public Properties

        let scenario: CleanerWindowPreview.Scenario

        var isXcodeRunning: Bool {
            scenario == .xcodeOpen || scenario == .confirmingWhileXcodeIsOpen
        }

        var isSimulatorRunning: Bool {
            scenario == .simulatorOpen
        }

        // MARK: - Public Methods

        func terminateSimulator() -> Bool {
            true
        }

    }
#endif

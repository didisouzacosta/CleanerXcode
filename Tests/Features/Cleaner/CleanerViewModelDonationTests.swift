//
//  CleanerViewModelDonationTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 09/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// The donation suggestion (C31): every successful cleanup is counted in the preferences, the
/// fifth, tenth… success suggests a donation instead of OK, and "Support the project" opens the
/// sheet, where only "Donate any amount" logs `donate`.
@MainActor
struct CleanerViewModelDonationTests {

    // MARK: - Private Properties

    private let catalog = CleanupCatalog(locations: CleanupLocations(
        home: URL(filePath: "/Users/qa", directoryHint: .isDirectory),
        userTemporary: URL(filePath: "/private/var/folders/qa/T", directoryHint: .isDirectory),
        systemTemporary: URL(filePath: "/private/tmp/qa", directoryHint: .isDirectory),
        varTemporary: URL(filePath: "/private/var/tmp/qa", directoryHint: .isDirectory)
    ))
    private let log = CallLog()
    private let analytics = AnalyticsStub()
    private let key = DonationPrompt.successfulCleanupCountKey

    /// The cleanup's own events are logged too; only `donate` matters here.
    private var donations: Int {
        analytics.events.filter { $0.name == "donate" }.count
    }

    // MARK: - Public Methods

    @Test
    func theKeyIsStable() {
        #expect(key == "successful-cleanup-count")
    }

    @Test
    func aSuccessIsCountedWithoutASuggestionAtFirst() async {
        let preferences = InMemoryPreferencesStore()
        let viewModel = makeViewModel(preferences: preferences)

        await clean(viewModel)

        #expect(viewModel.phase.report?.outcome == .success)
        #expect(preferences.integer(for: key) == 1)
        #expect(!viewModel.suggestsDonation)
    }

    /// The suggestion survives the measurement that follows the cleanup.
    @Test
    func theFifthSuccessSuggestsADonation() async {
        let preferences = seeded(4)
        let viewModel = makeViewModel(preferences: preferences)

        await clean(viewModel)

        #expect(preferences.integer(for: key) == 5)
        #expect(viewModel.suggestsDonation)
        #expect(viewModel.phase.report?.outcome == .success)
        #expect(viewModel.measurementCount == 2, "The cleanup measured again.")
        #expect(!viewModel.isShowingSupportSheet)
    }

    @Test
    func theSixthSuccessDoesNot() async {
        let preferences = seeded(5)
        let viewModel = makeViewModel(preferences: preferences)

        await clean(viewModel)

        #expect(preferences.integer(for: key) == 6)
        #expect(!viewModel.suggestsDonation)
    }

    /// Never on a partial failure, a failure, a permission denial or a cancel, which keep the count.
    @Test(arguments: UnsuccessfulRun.allCases)
    func otherOutcomesNeitherCountNorSuggest(run: UnsuccessfulRun) async {
        let preferences = seeded(4)
        let viewModel = makeViewModel(preferences: preferences, executor: CleanupExecutorSpy(reports: [run.report]))

        await clean(viewModel)

        #expect(viewModel.phase.report == run.report)
        #expect(preferences.integer(for: key) == 4)
        #expect(!viewModel.suggestsDonation)
    }

    /// The count lives in the real preferences, so it carries across launches.
    @Test
    func theCountPersistsAcrossInstances() async {
        let name = "donation.count"
        let defaults = TestPreferencesDomain.defaults(named: name)

        defer { TestPreferencesDomain.remove(named: name) }

        let store = UserDefaultsPreferencesStore(defaults: defaults)

        for _ in 0..<4 {
            await clean(makeViewModel(preferences: store))
        }

        let reopened = makeViewModel(preferences: UserDefaultsPreferencesStore(defaults: defaults))

        await clean(reopened)

        #expect(defaults.integer(forKey: key) == 5)
        #expect(reopened.suggestsDonation)
    }

    /// A missing or negative count starts over from zero.
    @Test
    func aNegativeCountStartsOver() async {
        let preferences = seeded(-3)
        let viewModel = makeViewModel(preferences: preferences)

        await clean(viewModel)

        #expect(preferences.integer(for: key) == 1)
        #expect(!viewModel.suggestsDonation)
    }

    @Test
    func theCountNeverOverflows() async {
        let preferences = seeded(.max)
        let viewModel = makeViewModel(preferences: preferences)

        await clean(viewModel)

        #expect(preferences.integer(for: key) == .max)
    }

    /// "Close" is the usual dismissal, with no event.
    @Test
    func closingDismissesTheReportAndTheSuggestion() async {
        let viewModel = makeViewModel(preferences: seeded(4))

        await clean(viewModel)
        viewModel.dismissReport()

        #expect(viewModel.phase == .ready)
        #expect(!viewModel.suggestsDonation)
        #expect(!viewModel.isShowingSupportSheet)
        #expect(donations == 0)
    }

    /// Opening the sheet consumes the suggestion and keeps the report, now with OK, without
    /// logging anything: only the sheet's donation does.
    @Test
    func supportingTheProjectOpensTheSheetWithoutAnEvent() async {
        let viewModel = makeViewModel(preferences: seeded(4))

        await clean(viewModel)
        viewModel.supportProject()

        #expect(viewModel.isShowingSupportSheet)
        #expect(!viewModel.suggestsDonation)
        #expect(viewModel.phase.report?.outcome == .success)
        #expect(donations == 0)
    }

    @Test
    func donatingFromTheSheetLogsOnceAndClosesIt() async {
        let viewModel = makeViewModel(preferences: seeded(4))

        await clean(viewModel)
        viewModel.supportProject()
        viewModel.donateFromSupportSheet()
        viewModel.donateFromSupportSheet()

        #expect(!viewModel.isShowingSupportSheet)
        #expect(donations == 1)
    }

    @Test
    func supportingWithoutASuggestionDoesNothing() async {
        let viewModel = makeViewModel()

        await clean(viewModel)
        viewModel.supportProject()
        viewModel.donateFromSupportSheet()

        #expect(!viewModel.isShowingSupportSheet)
        #expect(donations == 0)
    }

    @Test
    func notNowClosesTheSheetWithoutAnEvent() async {
        let viewModel = makeViewModel(preferences: seeded(4))

        await clean(viewModel)
        viewModel.supportProject()
        viewModel.dismissSupportSheet()

        #expect(!viewModel.isShowingSupportSheet)
        #expect(!viewModel.suggestsDonation)
        #expect(donations == 0)
    }

    /// A new cleanup closes the sheet and clears a suggestion left on screen.
    @Test
    func aNewCleanupClosesTheSheetAndClearsTheSuggestion() async {
        let preferences = seeded(4)
        let executor = CleanupExecutorSpy(reports: [
            CleanupReport(results: []),
            CleanupReport(results: [result(.failed(.inUse))]),
            CleanupReport(results: [result(.failed(.inUse))]),
        ])
        let viewModel = makeViewModel(preferences: preferences, executor: executor)

        await clean(viewModel)
        viewModel.supportProject()
        viewModel.dismissReport()
        await clean(viewModel)

        #expect(!viewModel.isShowingSupportSheet)
        #expect(viewModel.phase.report?.outcome == .failure)

        preferences.set(9, for: key)
        await viewModel.retryFailed()

        #expect(!viewModel.suggestsDonation)
        #expect(preferences.integer(for: key) == 9)
    }

    /// "Try again" that ends in success counts once.
    @Test
    func aSuccessfulRetryCounts() async {
        let preferences = seeded(4)
        let executor = CleanupExecutorSpy(reports: [
            CleanupReport(results: [result(.removed, id: .removeCaches), result(.failed(.inUse))]),
            CleanupReport(results: [result(.removed)]),
        ])
        let viewModel = makeViewModel(
            preferences: preferences,
            executor: executor,
            sizes: [.removeDerivedData: 1, .removeCaches: 1]
        )

        await clean(viewModel)

        #expect(viewModel.phase.report?.outcome == .partialFailure)
        #expect(preferences.integer(for: key) == 4)
        #expect(!viewModel.suggestsDonation)

        await viewModel.retryFailed()

        #expect(viewModel.phase.report?.outcome == .success)
        #expect(preferences.integer(for: key) == 5)
        #expect(viewModel.suggestsDonation)
    }

    // MARK: - Private Methods

    private func clean(_ viewModel: CleanerViewModel) async {
        await viewModel.refresh()
        await viewModel.requestClean()
    }

    private func seeded(_ count: Int) -> InMemoryPreferencesStore {
        let preferences = InMemoryPreferencesStore()

        preferences.set(count, for: key)
        return preferences
    }

    /// Derived Data and the caches are safe, so the plan runs without a confirmation.
    private func makeViewModel(
        preferences: any PreferencesStoring = InMemoryPreferencesStore(),
        executor: CleanupExecutorSpy = CleanupExecutorSpy(),
        sizes: [CleanupCategoryID: Int64] = [.removeDerivedData: 1]
    ) -> CleanerViewModel {
        var scannerSizes: [URL: Int64] = [:]

        for (id, size) in sizes {
            scannerSizes[catalog[id].targets[0].root] = size
        }

        for category in catalog.categories {
            preferences.setSelected(category.id, sizes.keys.contains(category.id))
        }

        return CleanerViewModel(
            catalog: catalog,
            measurer: CategorySizeMeasurer(scanner: DiskUsageScannerStub(sizes: scannerSizes)),
            simulators: SimulatorManagerStub(),
            executor: executor,
            preferences: preferences,
            runningApplications: RunningApplicationsFake(log: log),
            analytics: analytics,
            errorReporter: ErrorReporterStub(),
            appBundleIdentifier: "app.Cleaner",
            activationDebounce: .zero
        )
    }

    private func result(
        _ outcome: CleanupItemResult.Outcome,
        id: CleanupCategoryID = .removeDerivedData
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 100, outcome: outcome)
    }

}

// MARK: - Unsuccessful Runs

/// The outcomes that never count nor suggest a donation.
nonisolated enum UnsuccessfulRun: CaseIterable, Sendable {

    // MARK: - Cases

    case partialFailure
    case failure
    case permissionDenied
    case cancelled

    // MARK: - Public Properties

    var report: CleanupReport {
        switch self {
        case .partialFailure:
            CleanupReport(results: [result(.removed, id: .removeCaches), result(.failed(.inUse))])

        case .failure:
            CleanupReport(results: [result(.failed(.inUse))])

        case .permissionDenied:
            CleanupReport(results: [result(.failed(.permissionDenied))])

        case .cancelled:
            CleanupReport(results: [result(.removed)], wasCancelled: true)
        }
    }

    // MARK: - Private Methods

    private func result(
        _ outcome: CleanupItemResult.Outcome,
        id: CleanupCategoryID = .removeDerivedData
    ) -> CleanupItemResult {
        CleanupItemResult(categoryID: id, displayPath: "~/\(id.rawValue)", bytes: 100, outcome: outcome)
    }

}

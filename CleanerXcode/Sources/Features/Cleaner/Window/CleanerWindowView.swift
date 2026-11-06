//
//  CleanerWindowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The single window (R14, Figma page 08): a native sidebar with the overview, the four cleanup
/// sections, "Simulators and runtimes" and the Settings pages (C40), and a detail column that
/// scrolls under the fixed action bar. The selected page is kept per window; "Settings…" (⌘,) and
/// the panel's gear choose it through the `AppRouter`. The cleanup confirmation sheet lives here, so it
/// shows on any page and when the menu bar panel asks for it.
struct CleanerWindowView: View {

    // MARK: - States

    @SceneStorage("sidebar-destination") private var destination: SidebarDestination = .overview
    @State private var isShowingFailures: Bool

    // MARK: - Environments

    @Environment(\.appearsActive) private var appearsActive

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let simulators: SimulatorsViewModel
    let settings: SettingsViewModel
    let updates: UpdateViewModel
    let router: AppRouter
    let versionText: String
    /// Logs the donation; the footer opens the page.
    let onSupport: () -> Void

    var body: some View {
        NavigationSplitView {
            CleanerSidebarView(
                selection: $destination,
                viewModel: viewModel,
                simulators: simulators,
                updates: updates,
                versionText: versionText,
                onSupport: onSupport
            )
        } detail: {
            CleanerDetailView(
                destination: $destination,
                isShowingFailures: $isShowingFailures,
                viewModel: viewModel,
                simulators: simulators,
                settings: settings,
                updates: updates,
                versionText: versionText
            )
        }
        .sheet(isPresented: isConfirming) {
            CleanupConfirmationSheet(viewModel: viewModel)
        }
        .focusedSceneValue(\.sidebarDestination, $destination)
        .onChange(of: viewModel.phase.report) { oldReport, _ in
            closeFailures(after: oldReport)
        }
        .onChange(of: appearsActive, initial: true) {
            guard appearsActive else { return }

            activate()
        }
        // `initial` covers a window that "Settings…" has just opened.
        .onChange(of: router.pendingDestination, initial: true) {
            showPendingDestination()
        }
    }

    // MARK: - Private Properties

    /// Closing the sheet only cancels while it is still a confirmation, never a running cleanup.
    private var isConfirming: Binding<Bool> {
        Binding {
            if case .confirming = viewModel.phase {
                true
            } else {
                false
            }
        } set: { isPresented in
            guard !isPresented, case .confirming = viewModel.phase else { return }

            viewModel.cancel()
        }
    }

    // MARK: - Initializers

    /// Previews start on a page, with the failed items open.
    init(
        viewModel: CleanerViewModel,
        simulators: SimulatorsViewModel,
        settings: SettingsViewModel,
        updates: UpdateViewModel,
        router: AppRouter,
        versionText: String,
        initialDestination: SidebarDestination = .overview,
        isShowingFailuresInitially: Bool = false,
        onSupport: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self.simulators = simulators
        self.settings = settings
        self.updates = updates
        self.router = router
        self.versionText = versionText
        self.onSupport = onSupport
        _destination = SceneStorage(wrappedValue: initialDestination, "sidebar-destination")
        _isShowingFailures = State(initialValue: isShowingFailuresInitially)
    }

    // MARK: - Private Methods

    /// `OverviewPresentation.closesFailures` decides; a first report keeps the previews' state.
    private func closeFailures(after oldReport: CleanupReport?) {
        guard OverviewPresentation.closesFailures(whenReportChangesFrom: oldReport) else { return }

        isShowingFailures = false
    }

    private func showPendingDestination() {
        guard let pending = router.takePendingDestination() else { return }

        destination = pending
    }

    /// Measures past the debounce and the cache (R1), and lists the simulators only on the first
    /// activation, so the overview card and the sidebar badge have them (D9). Both tasks are
    /// unstructured: closing the window never turns them into a failure.
    private func activate() {
        Task { await viewModel.windowDidActivate() }
        Task { await simulators.loadOnActivation() }
    }

}

#if DEBUG
    #Preview("Ready") {
        CleanerWindowPreview(.ready)
    }

    #Preview("Measuring") {
        CleanerWindowPreview(.measuring)
    }

    #Preview("Nothing selected") {
        CleanerWindowPreview(.nothingSelected)
    }

    #Preview("Nothing to clean") {
        CleanerWindowPreview(.nothingToClean)
    }

    #Preview("Danger confirmation") {
        CleanerWindowPreview(.confirming)
    }

    #Preview("Confirmation with Xcode open") {
        CleanerWindowPreview(.confirmingWhileXcodeIsOpen)
    }

    #Preview("Cleaning") {
        CleanerWindowPreview(.cleaning)
    }

    #Preview("Cancelling") {
        CleanerWindowPreview(.cancelling)
    }

    #Preview("Success") {
        CleanerWindowPreview(.finished(.success))
    }

    #Preview("Partial failure") {
        CleanerWindowPreview(.finished(.partialFailure))
    }

    #Preview("Partial failure · details open") {
        CleanerWindowPreview(.finished(.partialFailure), isShowingFailures: true)
    }

    #Preview("Failure") {
        CleanerWindowPreview(.finished(.failure))
    }

    #Preview("Cancelled") {
        CleanerWindowPreview(.finished(.cancelled))
    }

    #Preview("Permission denied") {
        CleanerWindowPreview(.permissionDenied)
    }

    #Preview("Xcode open") {
        CleanerWindowPreview(.xcodeOpen)
    }

    #Preview("User data · Xcode open") {
        CleanerWindowPreview(.xcodeOpen, destination: .userData)
    }

    #Preview("Simulator open") {
        CleanerWindowPreview(.simulatorOpen)
    }

    #Preview("Xcode tools unavailable") {
        CleanerWindowPreview(.toolsUnavailable)
    }

    #Preview("Xcode page") {
        CleanerWindowPreview(.ready, destination: .xcode)
    }

    #Preview("Simulators and runtimes page") {
        CleanerWindowPreview(.ready, destination: .simulatorsAndRuntimes)
    }

    #Preview("Minimum size") {
        CleanerWindowPreview(.ready, size: CGSize(width: 760, height: 520))
    }

    #Preview("Up to date") {
        CleanerWindowPreview(.ready, hasUpdate: false)
    }

    #Preview("Dark · Overview · 760") {
        CleanerWindowPreview(.ready, size: CGSize(width: 760, height: 520))
            .preferredColorScheme(.dark)
    }

    #Preview("Dark · Overview · 1500") {
        CleanerWindowPreview(.ready, size: CGSize(width: 1_500, height: 620))
            .preferredColorScheme(.dark)
    }

    #Preview("Reduce transparency") {
        CleanerWindowPreview(.ready, reducesTransparency: true)
    }

    #Preview("Dark") {
        CleanerWindowPreview(.ready)
            .preferredColorScheme(.dark)
    }

    #Preview("Dark · Xcode page") {
        CleanerWindowPreview(.ready, destination: .xcode)
            .preferredColorScheme(.dark)
    }

    #Preview("Dark · Success") {
        CleanerWindowPreview(.finished(.success))
            .preferredColorScheme(.dark)
    }

    #Preview("Dark · Simulators and runtimes") {
        CleanerWindowPreview(.ready, destination: .simulatorsAndRuntimes)
            .preferredColorScheme(.dark)
    }
#endif

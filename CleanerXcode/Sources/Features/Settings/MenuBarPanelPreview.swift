//
//  MenuBarPanelPreview.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

#if DEBUG
    import SwiftUI

    /// Drives the panel with the same fakes as the window previews (`CleanerWindowPreview`).
    struct MenuBarPanelPreview: View {

        // MARK: - States

        @State private var viewModel: CleanerViewModel
        @State private var router = AppRouter()

        // MARK: - Public Properties

        var body: some View {
            MenuBarPanelView(viewModel: viewModel, router: router, isDeletingSimulators: isDeletingSimulators)
                .task {
                    await prepare()
                }
        }

        // MARK: - Private Properties

        private let scenario: Scenario
        private let isDeletingSimulators: Bool

        // MARK: - Initializers

        init(_ scenario: Scenario, isDeletingSimulators: Bool = false) {
            self.scenario = scenario
            self.isDeletingSimulators = isDeletingSimulators
            _viewModel = State(initialValue: CleanerWindowPreview.makeViewModel(for: scenario.windowScenario))
        }

        // MARK: - Private Methods

        private func prepare() async {
            switch scenario {
            case .review:
                // Archives is selected but not requested, so the panel offers "Review and clean…".
                await viewModel.refresh()

            default:
                await CleanerWindowPreview.prepare(viewModel, for: scenario.windowScenario)
            }
        }

        // MARK: - Nested Types

        enum Scenario {

            // MARK: - Cases

            case ready
            case measuring
            case review
            case cleaning
            case finished(CleanupReport.Outcome)
            case permissionDenied

            // MARK: - Public Properties

            var windowScenario: CleanerWindowPreview.Scenario {
                switch self {
                case .ready: .ready
                case .measuring: .measuring
                case .review: .confirming
                case .cleaning: .cleaning
                case let .finished(outcome): .finished(outcome)
                case .permissionDenied: .permissionDenied
                }
            }

        }

    }

    /// The menu bar label with and without the size, and while cleaning.
    struct MenuBarLabelPreview: View {

        // MARK: - States

        @State private var ready = CleanerWindowPreview.makeViewModel(for: .ready)
        @State private var cleaning = CleanerWindowPreview.makeViewModel(for: .cleaning)

        // MARK: - Public Properties

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                MenuBarLabelView(viewModel: ready, showsSize: true)
                MenuBarLabelView(viewModel: ready, showsSize: false)
                MenuBarLabelView(viewModel: cleaning, showsSize: true)
            }
            .padding()
            .task {
                await ready.refresh()
                await CleanerWindowPreview.prepare(cleaning, for: .cleaning)
            }
        }

    }
#endif

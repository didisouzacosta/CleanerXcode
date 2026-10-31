//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@main
struct CleanerXcodeApp: App {

    // MARK: - States

    @State private var updateViewModel: UpdateViewModel
    @State private var cleanerViewModel: CleanerViewModel
    @State private var simulatorsViewModel: SimulatorsViewModel
    @State private var settingsViewModel: SettingsViewModel

    // MARK: - Environments

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    // MARK: - Private Variables

    private let environment: AppEnvironment

    private var versionText: String {
        "\(Bundle.main.version) (\(Bundle.main.build))"
    }

    /// Optional (R14); removing the item from the menu bar turns the setting off. The test host
    /// keeps it inserted, as before: hiding it would save its visibility in the app's domain.
    private var showsMenuBarExtra: Binding<Bool> {
        guard !environment.isRunningTests else { return .constant(true) }

        return Binding {
            settingsViewModel.showsMenuBarExtra
        } set: { isInserted in
            settingsViewModel.setShowsMenuBarExtra(isInserted)
        }
    }

    // MARK: - Public Variables

    var body: some Scene {
        // The single window (R14). It opens at launch.
        Window("CleanerXcode", id: "main") {
            CleanerWindowView(
                viewModel: cleanerViewModel,
                simulators: simulatorsViewModel,
                updates: updateViewModel,
                versionText: versionText
            ) {
                settingsViewModel.logDonation()
            }
            .frame(minWidth: 480, minHeight: 560)
            .task {
                // Inert in the test host and previews; errors stay silent (R16).
                await updateViewModel.check()
            }
        }
        .defaultSize(width: 560, height: 720)
        .windowResizability(.contentMinSize)
        // The test host never opens it, so tests leave no window state in the app's domain.
        .defaultLaunchBehavior(environment.isRunningTests ? .suppressed : .presented)

        Settings {
            SettingsView(viewModel: settingsViewModel, updates: updateViewModel, versionText: versionText)
        }

        MenuBarExtra(isInserted: showsMenuBarExtra) {
            MenuBarPanelView(viewModel: cleanerViewModel, isDeletingSimulators: simulatorsViewModel.phase.isDeleting)
        } label: {
            MenuBarLabelView(viewModel: cleanerViewModel, showsSize: settingsViewModel.showsSizeInMenuBar)
        }
        .menuBarExtraStyle(.window)
    }

    // MARK: - Initializers

    init() {
        let environment = AppEnvironment.current()
        let services = AppContainer.makeServices(
            environment: environment,
            configuration: AppConfiguration(infoDictionary: Bundle.main.infoDictionary ?? [:])
        )
        let cleanerViewModel = AppContainer.makeCleanerViewModel(environment: environment, services: services)

        self.environment = environment
        _updateViewModel = .init(initialValue: AppContainer.makeUpdateViewModel(
            environment: environment,
            services: services
        ))
        _cleanerViewModel = .init(initialValue: cleanerViewModel)
        // Deleting simulators or a runtime changes the sizes, so the window measures again.
        _simulatorsViewModel = .init(initialValue: AppContainer.makeSimulatorsViewModel(
            environment: environment,
            services: services
        ) {
            await cleanerViewModel.refresh()
        })
        _settingsViewModel = .init(initialValue: AppContainer.makeSettingsViewModel(
            environment: environment,
            services: services
        ) { days in
            Task { await cleanerViewModel.setMinimumTemporaryAgeInDays(days) }
        })
    }

}

/// Closing the last window quits only when the menu bar item is off (R14).
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Public Methods

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let store = UserDefaultsPreferencesStore()
        let showsMenuBarExtra = store.bool(for: PreferencesMigrator.showMenuBarExtraKey) ?? true

        return MenuBarPresentation.quitsAfterLastWindowClosed(showsMenuBarExtra: showsMenuBarExtra)
    }

}

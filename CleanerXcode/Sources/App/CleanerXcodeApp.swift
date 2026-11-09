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
    @State private var router = AppRouter()
    /// The menu bar icon's background measurement (C40); `nil` in the test host and previews.
    @State private var backgroundMeasurement: BackgroundMeasurementScheduler?

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
        // The single window (R14). It opens at launch with a common size (Figma page 08); it is
        // resizable and macOS keeps its frame. The content scrolls, so nothing fits the height.
        // Settings are pages of its sidebar since C40, so the app has no Settings scene.
        Window("CleanerXcode", id: WindowID.main) {
            CleanerWindowView(
                viewModel: cleanerViewModel,
                simulators: simulatorsViewModel,
                settings: settingsViewModel,
                updates: updateViewModel,
                router: router,
                versionText: versionText
            ) {
                settingsViewModel.logDonation()
            }
            .frame(minWidth: 760, minHeight: 520)
            .task {
                // Inert in the test host and previews; errors stay silent (R16).
                await updateViewModel.check()
            }
            .task {
                await runDemoIfNeeded()
            }
        }
        .defaultSize(width: 920, height: 620)
        .windowResizability(.contentMinSize)
        // The test host never opens it, so tests leave no window state in the app's domain.
        .defaultLaunchBehavior(environment.isRunningTests ? .suppressed : .presented)
        .commands {
            SidebarCommands()
            CleanerCommands(router: router)
        }

        MenuBarExtra(isInserted: showsMenuBarExtra) {
            MenuBarPanelView(
                viewModel: cleanerViewModel,
                router: router,
                isDeletingSimulators: simulatorsViewModel.phase.isDeleting
            )
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
        // Deleting simulators or a runtime changes the sizes, so the window measures again.
        let simulatorsViewModel = AppContainer.makeSimulatorsViewModel(
            environment: environment,
            services: services
        ) {
            await cleanerViewModel.refresh()
        }

        let settingsViewModel = AppContainer.makeSettingsViewModel(
            environment: environment,
            services: services
        ) { days in
            Task { await cleanerViewModel.setMinimumTemporaryAgeInDays(days) }
        }
        // Only with the menu bar item and its size on: otherwise there is no number to keep, and
        // the window or the panel measure when they open. Read on every tick.
        let backgroundMeasurement = AppContainer.makeBackgroundMeasurementScheduler(
            environment: environment,
            measuring: cleanerViewModel,
            isEnabled: { settingsViewModel.showsMenuBarExtra && settingsViewModel.showsSizeInMenuBar },
            isBusy: { simulatorsViewModel.phase.isDeleting }
        )

        self.environment = environment
        _updateViewModel = .init(initialValue: AppContainer.makeUpdateViewModel(
            environment: environment,
            services: services
        ))
        _cleanerViewModel = .init(initialValue: cleanerViewModel)
        _simulatorsViewModel = .init(initialValue: simulatorsViewModel)
        _settingsViewModel = .init(initialValue: settingsViewModel)
        _backgroundMeasurement = .init(initialValue: backgroundMeasurement)

        if !environment.isInert {
            Self.observeAppLifecycle(simulators: simulatorsViewModel, backgroundMeasurement: backgroundMeasurement)
            backgroundMeasurement?.start()
        }

        #if DEBUG
            if environment.isDemo {
                DemoSession.applyAppearance()
            }
        #endif
    }

    // MARK: - Private Methods

    /// Quitting cancels a runtime download, so no `xcodebuild` is left running (C30, R9), and ends
    /// the background measurement loop and the live measurement's stream (C40); a measurement in
    /// progress is read-only and ends with the process. Cancelling runs the cancellation handlers
    /// at once, so the process is terminated before the app ends. The system's sleep stops the
    /// loop and the wake starts it again, so a late tick never fires the moment the Mac wakes. The
    /// observers last as long as the app, so their tokens are never removed.
    private static func observeAppLifecycle(
        simulators: SimulatorsViewModel,
        backgroundMeasurement: BackgroundMeasurementScheduler?
    ) {
        _ = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                simulators.cancelRuntimeDownload()
                backgroundMeasurement?.stop()
            }
        }

        let workspaceCenter = NSWorkspace.shared.notificationCenter

        _ = workspaceCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                backgroundMeasurement?.systemWillSleep()
            }
        }

        _ = workspaceCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated {
                backgroundMeasurement?.systemDidWake()
            }
        }

        // Low Power Mode and the thermal state pause the live measurement (C40 · tempo real).
        // ProcessInfo posts them on a global queue; `.main` delivers them on the main thread.
        for name in [ProcessInfo.thermalStateDidChangeNotification, .NSProcessInfoPowerStateDidChange] {
            _ = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    backgroundMeasurement?.conditionsDidChange()
                }
            }
        }
    }

    /// The demo's tour of the window (C36), only in Debug builds started with `CLEANERXCODE_DEMO=1`.
    private func runDemoIfNeeded() async {
        #if DEBUG
            guard environment.isDemo else { return }

            await DemoSession.run(
                viewModel: cleanerViewModel,
                simulators: simulatorsViewModel,
                router: router,
                startDelay: environment.demoStartDelay
            )
        #endif
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

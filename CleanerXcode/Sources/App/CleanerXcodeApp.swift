//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import LaunchAtLogin
import SwiftUI

@main
struct CleanerXcodeApp: App {

    // MARK: - States

    @State private var isFirstOpen = true
    @State private var route = Route()

    @State private var analytics: AnalyticsTracker
    @State private var updateStore: UpdateStore
    @State private var preferences: Preferences
    @State private var cleanerStore: CleanerStore
    @State private var cleanerViewModel: CleanerViewModel

    // MARK: - Private Variables

    private let environment: AppEnvironment

    // MARK: - Public Variables

    var body: some Scene {
        // The single window (R14). It opens at launch; the menu bar item stays until C22.
        Window("CleanerXcode", id: "main") {
            CleanerWindowView(
                viewModel: cleanerViewModel,
                updates: updateStore,
                versionText: "\(Bundle.main.version) (\(Bundle.main.build))"
            )
            .frame(minWidth: 480, minHeight: 560)
        }
        .defaultSize(width: 560, height: 720)
        .windowResizability(.contentMinSize)
        // The test host never opens it, so tests leave no window state in the app's domain.
        .defaultLaunchBehavior(environment.isRunningTests ? .suppressed : .presented)

        // Hosts the current preferences until C22 brings the new Settings.
        Settings {
            PreferencesView()
                .frame(width: 340)
                .environment(route)
                .environment(cleanerStore)
                .environment(preferences)
                .environment(analytics)
        }

        MenuBarExtra {
            MainView()
                .frame(width: 340)
                .environment(route)
                .environment(cleanerStore)
                .environment(updateStore)
                .environment(preferences)
                .environment(analytics)
        } label: {
            HStack {
                Image("iconClear")

                if preferences.displayFreeUpSpaceInMenuBar.value {
                    if cleanerStore.status == .isCleaning {
                        Text("Cleaning")
                    } else if cleanerStore.isCalculating, isFirstOpen {
                        Text("Calculating")
                            .onAppear {
                                isFirstOpen = false
                            }
                    } else {
                        Text(cleanerStore.freeUpSpace.byteFormatter())
                    }
                }
            }
            .onAppear {
                // The test host and previews must not register login items or reach the network.
                guard !environment.isRunningTests, !environment.isRunningPreviews else { return }

                LaunchAtLogin.isEnabled = preferences.launchAtLogin.value
                updateStore.checkUpdates()
            }
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
        let preferences = services.preferences

        self.environment = environment
        _analytics = .init(initialValue: AnalyticsTracker(services.analytics))
        _updateStore = .init(initialValue: .init(Bundle.main))
        _preferences = .init(initialValue: preferences)
        _cleanerStore = .init(initialValue: .init(
            commandExecutor: services.commandExecutor,
            preferences: preferences,
            analytics: services.analytics,
            errorReporter: services.errorReporter
        ))
        _cleanerViewModel = .init(initialValue: AppContainer.makeCleanerViewModel(
            environment: environment,
            services: services
        ))
    }

}

private extension CleanerStore {

    var isCalculating: Bool {
        usedSpace.isLoading && usedSpace.value.totalSize == 0
    }

}

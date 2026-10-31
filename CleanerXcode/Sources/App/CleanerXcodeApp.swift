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

    // MARK: - Private Variables

    private let environment: AppEnvironment

    // MARK: - Public Variables

    var body: some Scene {
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
    }

}

private extension CleanerStore {

    var isCalculating: Bool {
        usedSpace.isLoading && usedSpace.value.totalSize == 0
    }

}

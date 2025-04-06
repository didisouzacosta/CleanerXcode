//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI
import Mixpanel
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        Mixpanel.initialize(token: Bundle.main.mixpanelToken)
        #endif
    }
    
}

@main
struct CleanerXcodeApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    
    // MARK: - States
    
    @State private var isFirstOpen = true
    @State private var route = Route()
    @State private var cleanerStore = CleanerStore(commandExecutor: Shell(), preferences: .shared, analytics: MixpanelAnalytics.shared)
    @State private var updateStore = UpdateStore(Bundle.main)
    @State private var preferences = Preferences.shared
    
    // MARK: - Private Variables
    
    private let analytics = MixpanelAnalytics.shared
    
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
                    } else if cleanerStore.isCalculating && isFirstOpen {
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
                LaunchAtLogin.isEnabled = preferences.launchAtLogin.value
                updateStore.checkUpdates()
            }
        }
        .menuBarExtraStyle(.window)
    }
    
}

fileprivate extension CleanerStore {
    
    var isCalculating: Bool {
        usedSpace.isLoading && usedSpace.value.totalSize == 0
    }
    
}

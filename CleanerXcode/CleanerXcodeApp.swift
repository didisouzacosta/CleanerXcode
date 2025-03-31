//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI
import FirebaseCore
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        FirebaseApp.configure()
    }
    
}

@main
struct CleanerXcodeApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    
    // MARK: - Private Variables
    
    private var route = Route()
    private var clearStore = ClearStore(.shared, analytics: Analytics.shared)
    private var updateStore = UpdateStore(Bundle.main)
    private var preferences = Preferences.shared
    
    // MARK: - Private Variables
    
    private let analytics = Analytics.shared
    
    // MARK: - Public Variables
    
    var body: some Scene {
        MenuBarExtra {
            MainView()
                .frame(width: 340)
                .environment(\.route, route)
                .environment(\.clearStore, clearStore)
                .environment(\.updateStore, updateStore)
                .environment(\.preferences, preferences)
                .environment(\.analytics, analytics)
        } label: {
            HStack {
                Image("iconClear")
                
                if preferences.displayFreeUpSpaceInMenuBar.value {
                    if clearStore.isCleaning {
                        Text("Cleaning...")
                    } else if clearStore.usedSpace.isLoading && clearStore.usedSpace.value.totalSize == 0 {
                        Text("Calculating...")
                    } else {
                        Text(clearStore.freeUpSpace.byteFormatter())
                    }
                }
            }
            .onAppear {
                LaunchAtLogin.isEnabled = preferences.launchAtLogin.value
//                updateStore.checkUpdates()
            }
        }
        .menuBarExtraStyle(.window)
    }
    
}

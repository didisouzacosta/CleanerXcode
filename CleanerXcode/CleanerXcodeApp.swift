//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI
import Firebase
import LaunchAtLogin

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        #if !DEBUG
        FirebaseApp.configure()
        #endif
    }
    
}

@main
struct CleanerXcodeApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    
    // MARK: - States
    
    @State private var isFirstOpen = true
    @State private var route = Route()
    
    @State private var analytics: GoogleAnalytics
    @State private var updateStore: UpdateStore
    @State private var preferences: Preferences
    @State private var cleanerStore: CleanerStore
    
    // MARK: - Private Variables
    
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
    
    // MARK: - Initializers
    
    init() {
        let commander = Shell()
        let preferences = Preferences()
        let analytics = GoogleAnalytics()
        
        _analytics = .init(initialValue: analytics)
        _updateStore = .init(initialValue: .init(Bundle.main))
        _preferences = .init(initialValue: preferences)
        _cleanerStore = .init(initialValue: .init(
            commandExecutor: commander,
            preferences: preferences,
            analytics: analytics
        ))
    }
    
}

fileprivate extension CleanerStore {
    
    var isCalculating: Bool {
        usedSpace.isLoading && usedSpace.value.totalSize == 0
    }
    
}

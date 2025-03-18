//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI
import FirebaseCore

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
    
    private let preferences: Preferences
    private let route: Route
    private let clearStore: ClearStore
    private let analytics: Analytics
    
    // MARK: - Public Variables
    
    var body: some Scene {
        MenuBarExtra {
            MainView()
                .frame(width: 280)
                .environment(\.route, route)
                
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
        .environment(\.clearStore, clearStore)
        .environment(\.preferences, preferences)
        .environment(\.analytics, analytics)
    }
    
    init() {
        self.preferences = Preferences()
        self.route = Route()
        self.analytics = Analytics()
        self.clearStore = .init(preferences, analytics: analytics)
    }
    
}

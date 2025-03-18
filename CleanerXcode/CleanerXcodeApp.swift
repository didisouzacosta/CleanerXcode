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
    
    @State private var preferences: Preferences
    @State private var clearStore: ClearStore
    @State private var route: Route
    
    private let analytics: Analytics
    
    // MARK: - Public Variables
    
    var body: some Scene {
        MenuBarExtra {
            MainView()
                .frame(width: 280)
                .environment(\.route, route)
                .environment(\.clearStore, clearStore)
                .environment(\.preferences, preferences)
                .environment(\.analytics, analytics)
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
    }
    
    init() {
        let preferences = Preferences()
        let route = Route()
        let analytics = Analytics()
        let clearStore = ClearStore(preferences, analytics: analytics)
        
        self.analytics = analytics
        
        _preferences = .init(wrappedValue: preferences)
        _route = .init(wrappedValue: route)
        _clearStore = .init(wrappedValue: clearStore)
    }
    
}

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
        FirebaseApp.configure()
    }
    
}

@main
struct CleanerXcodeApp: App {
    
    // MARK: - States
    
    @State private var preferences = Preferences()
    @State private var route = Route()
    
    // MARK: - Private Variables
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    
    private let analytics = Analytics()
    
    // MARK: - Public Variables
    
    var body: some Scene {
        let clearStore = ClearStore(preferences, analytics: analytics)
        
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
    
}

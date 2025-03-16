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
    
    @State private var preferences = Preferences()
    @State private var route = Route()
    
    // MARK: - Public Variables
    
    var body: some Scene {
        let clearStore = ClearStore(preferences)
        
        MenuBarExtra {
            Group {
                if route.isPresentSettings {
                    PreferencesView()
                        .transition(.move(edge: .trailing))
                } else {
                    HomeView()
                        .transition(.move(edge: .leading))
                }
            }
            .frame(width: 280)
            .animation(.easeInOut, value: route.isPresentSettings)
            .environment(\.clearStore, clearStore)
            .environment(\.preferences, preferences)
            .environment(\.route, route)
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
    }
    
}

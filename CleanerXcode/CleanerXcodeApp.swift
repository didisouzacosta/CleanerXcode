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
    @State private var navigation = Navigation()
    
    // MARK: - Public Variables
    
    var body: some Scene {
        let clearStore = ClearStore(preferences)
        
        MenuBarExtra {
            Group {
                if navigation.isPresentSettings {
                    PreferencesView()
                        .transition(.move(edge: .trailing))
                } else {
                    HomeView()
                        .transition(.move(edge: .leading))
                }
            }
            .frame(width: 280)
            .animation(.easeInOut, value: navigation.isPresentSettings)
            .environment(\.clearStore, clearStore)
            .environment(\.preferences, preferences)
            .environment(\.navigation, navigation)
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
    }
    
}

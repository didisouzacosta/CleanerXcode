//
//  CleanerXcodeApp.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI
import FluidMenuBarExtra

@main
struct CleanerXcodeApp: App {
    
    // MARK: - Private Variables
    
    private let preferences = Preferences()
    
    @State private var test = false
    
    // MARK: - Public Variables
    
    var body: some Scene {
        let clearStore = ClearStore(preferences)
        
        MenuBarExtra {
            Group {
                if test {
                    PreferencesView($test)
                        .transition(.move(edge: .trailing))
                } else {
                    HomeView($test)
                        .transition(.move(edge: .leading))
                }
            }
            .frame(width: 280)
            .animation(.easeInOut, value: test)
        } label: {
            Image("iconClear")
        }
        .menuBarExtraStyle(.window)
        .environment(\.clearStore, clearStore)
        .environment(\.preferences, preferences)
    }
    
}

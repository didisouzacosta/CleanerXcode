//
//  MainView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 16/03/25.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - Environments
    
    @Environment(\.route) private var route
    
    // MARK: - Public Variables
    
    var body: some View {
        Group {
            if route.isPresentSettings {
                PreferencesView()
                    .transition(.move(edge: .trailing))
            } else {
                CleanerView()
                    .transition(.move(edge: .leading))
            }
        }
    }
    
}

#Preview {
    MainView()
        .environment(\.preferences, .init())
        .environment(\.route, .init())
}

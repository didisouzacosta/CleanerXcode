//
//  MainView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 16/03/25.
//

import SwiftUI

struct MainView: View {
    
    // MARK: - Environments
    
    @Environment(Route.self) private var route
    
    // MARK: - Public Variables
    
    var body: some View {
        Group {
            switch route.path {
            case .cleaner:
                CleanerView()
                    .transition(.move(edge: .leading))
            case .preferences:
                PreferencesView()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut, value: route.path)
    }
    
}

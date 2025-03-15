//
//  Navigation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

@Observable
final class Navigation {
    
    // MARK: - Public Variables
    
    var isPresentSettings = false
    
    // MARK: - Initializers
    
    init() {}
    
}

extension EnvironmentValues {
    
    @Entry var navigation = Navigation()
    
}

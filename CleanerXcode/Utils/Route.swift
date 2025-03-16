//
//  Route.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

@Observable
final class Route {
    
    // MARK: - Public Variables
    
    var isPresentSettings = false
    
    // MARK: - Initializers
    
    init() {}
    
}

extension EnvironmentValues {
    
    @Entry var route = Route()
    
}

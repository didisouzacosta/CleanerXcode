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
    
    var path: Path = .cleaner
    
    // MARK: - Initializers
    
    init() {}
    
}

extension Route {
    
    enum Path: Int, Hashable {
        case cleaner = 0
        case preferences
    }
    
}

extension EnvironmentValues {
    
    @Entry var route = Route()
    
}

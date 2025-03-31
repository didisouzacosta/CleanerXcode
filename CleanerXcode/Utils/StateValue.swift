//
//  StateValue.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 25/03/25.
//

import Foundation

struct StateValue<T: Equatable> {
    
    // MARK: - Public Variables
    
    var isLoading = false
    
    var value: T {
        didSet {
            isLoading = false
            error = nil
        }
    }
    
    var error: Error? {
        didSet {
            isLoading = false
        }
    }
    
    // MARK: - Initializers
    
    init(_ value: T) {
        self.value = value
    }
    
}

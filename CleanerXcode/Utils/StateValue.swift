//
//  StateValue.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 25/03/25.
//

import Foundation

struct StateValue<T: Equatable> {
    
    private(set) var value: T
    
    var state: State {
        didSet {
            switch state {
            case .success(let value):
                self.value = value
            default: return
            }
        }
    }
    
    init(_ value: T, state: State) {
        self.value = value
        self.state = state
    }
    
}

extension StateValue {
    
    enum State {
        case isLoading
        case failure(any Error)
        case success(T)
    }
    
    var error: Error? {
        switch state {
        case .failure(let error): error
        default: nil
        }
    }
    
    var isLoading: Bool {
        switch state {
        case .isLoading: true
        default: false
        }
    }
    
}

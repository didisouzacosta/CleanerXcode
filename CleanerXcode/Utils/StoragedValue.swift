//
//  StoragedValue.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

@Observable
final class StoragedValue<T: Codable> {
    
    // MARK: - Public Variables
    
    private(set) var key: String
    
    var value: T {
        didSet {
            if let data = try? JSONEncoder().encode(value) {
                userDefaults.setValue(data, forKey: key)
            }
        }
    }
    
    // MARK: - Private Variables
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initializers
    
    init(
        _ key: String,
        value: T? = nil,
        defaultValue: T,
        userDefaults: UserDefaults = .standard
    ) {
        self.key = key
        self.userDefaults = userDefaults
        
        if let data = userDefaults.value(forKey: key) as? Data,
           let value = try? JSONDecoder().decode(T.self, from: data) {
            self.value = value
        } else {
            self.value = value ?? defaultValue
        }
    }
    
}

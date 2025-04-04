//
//  UserDefaults+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Foundation

extension UserDefaults {
    
    static let test = UserDefaults(suiteName: "test")!
    
    func reset() {
        dictionaryRepresentation().keys.forEach { key in
            removeObject(forKey: key)
        }
    }
    
}

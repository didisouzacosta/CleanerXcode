//
//  UserDefaults+Extension.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Foundation

extension UserDefaults {

    // MARK: - Test Suite

    static let test: UserDefaults = {
        guard let defaults = UserDefaults(suiteName: "test") else {
            preconditionFailure("Could not create the test UserDefaults suite.")
        }

        return defaults
    }()

    func reset() {
        for key in dictionaryRepresentation().keys {
            removeObject(forKey: key)
        }
    }

}

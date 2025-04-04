//
//  StoragedValueTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct StoragedValueTests {

    private let userDefaults = UserDefaults.test
    
    init() {
        userDefaults.reset()
    }
    
    @Test
    func ensureConsistencyOfStoragedValue() async throws {
        let storagedValue = StoragedValue(
            "isAgree",
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        var value: Bool? = try userDefaults.decoderValue("isAgree")
        
        #expect(storagedValue.value == false)
        #expect(value == nil)
        
        storagedValue.value = true
        
        value = try userDefaults.decoderValue("isAgree")
        
        #expect(value == true)
    }

}

fileprivate extension UserDefaults {
    
    func decoderValue<T: Codable>(_ key: String) throws -> T? {
        guard let data = value(forKeyPath: key) as? Data else {
            return nil
        }
        
        return try JSONDecoder().decode(T.self, from: data)
    }
    
}

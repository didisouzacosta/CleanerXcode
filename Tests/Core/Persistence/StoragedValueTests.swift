//
//  StoragedValueTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct StoragedValueTests {

    // MARK: - Private Properties

    private let userDefaults = UserDefaults.test

    init() {
        userDefaults.reset()
    }

    @Test
    func ensureConsistencyOfStoragedValue() throws {
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

private extension UserDefaults {

    func decoderValue<T: Codable>(_ key: String) throws -> T? {
        guard let data = value(forKeyPath: key) as? Data else {
            return nil
        }

        return try JSONDecoder().decode(T.self, from: data)
    }

}

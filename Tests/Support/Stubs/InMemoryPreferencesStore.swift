//
//  InMemoryPreferencesStore.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

@testable import CleanerXcode

final class InMemoryPreferencesStore: PreferencesStoring {

    // MARK: - Public Properties

    private(set) var values: [String: StoredBool]
    private(set) var schemaVersion: Int
    private(set) var writeCount = 0

    // MARK: - Initializers

    init(_ values: [String: StoredBool] = [:], schemaVersion: Int = 0) {
        self.values = values
        self.schemaVersion = schemaVersion
    }

    // MARK: - Public Methods

    func storedValue(for key: String) -> StoredBool {
        values[key] ?? .missing
    }

    func set(_ value: Bool, for key: String) {
        values[key] = .value(value)
        writeCount += 1
    }

    func removeValue(for key: String) {
        values[key] = nil
        writeCount += 1
    }

    func setSchemaVersion(_ version: Int) {
        schemaVersion = version
        writeCount += 1
    }

}

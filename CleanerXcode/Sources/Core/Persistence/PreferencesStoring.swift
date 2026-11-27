//
//  PreferencesStoring.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

/// A saved switch, telling a missing key apart from one that cannot be read.
enum StoredBool: Equatable, Sendable {
    case missing
    case value(Bool)
    case corrupted
}

protocol PreferencesStoring: AnyObject {
    var schemaVersion: Int { get }

    func storedValue(for key: String) -> StoredBool
    func set(_ value: Bool, for key: String)
    /// `nil` when missing or not a number.
    func integer(for key: String) -> Int?
    func set(_ value: Int, for key: String)
    func removeValue(for key: String)
    func setSchemaVersion(_ version: Int)
}

extension PreferencesStoring {

    // MARK: - Public Methods

    /// `nil` for a missing or corrupted value, so the caller falls back to the default.
    func bool(for key: String) -> Bool? {
        guard case let .value(value) = storedValue(for: key) else { return nil }

        return value
    }

    /// The category IDs are the legacy preference keys (R3).
    func isSelected(_ id: CleanupCategoryID) -> Bool? {
        bool(for: id.rawValue)
    }

    func setSelected(_ id: CleanupCategoryID, _ value: Bool) {
        set(value, for: id.rawValue)
    }

}

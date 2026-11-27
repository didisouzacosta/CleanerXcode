//
//  LossyElement.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// An element of a decoded list that may not read: `value` is `nil` instead of failing the whole
/// list, so one unexpected entry of an undocumented format never hides the others (C35, P4). It
/// encodes as its value.
nonisolated struct LossyElement<Value: Decodable>: Decodable {

    // MARK: - Public Properties

    let value: Value?

    // MARK: - Initializers

    init(value: Value?) {
        self.value = value
    }

    init(from decoder: any Decoder) {
        value = try? Value(from: decoder)
    }

}

nonisolated extension LossyElement: Encodable where Value: Encodable {

    // MARK: - Public Methods

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()

        try container.encode(value)
    }

}

//
//  RiskLevel.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated enum RiskLevel: Int, Comparable, Sendable, Hashable {
    case safe
    case attention
    case dangerous

    // MARK: - Public Methods

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

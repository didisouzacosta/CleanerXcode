//
//  CleanupCategory.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

nonisolated struct CleanupCategory: Identifiable, Sendable, Hashable {

    // MARK: - Public Properties

    let id: CleanupCategoryID
    /// What is measured and, for file operations, what is cleaned.
    let targets: [CleanupTarget]
    let operation: CleanupOperation
    let risk: RiskLevel
    let isEnabledByDefault: Bool
    let isBlockedWhileXcodeRuns: Bool
    let restartsSimulatorService: Bool

    // MARK: - Initializers

    init(
        id: CleanupCategoryID,
        targets: [CleanupTarget],
        operation: CleanupOperation,
        risk: RiskLevel,
        isEnabledByDefault: Bool,
        isBlockedWhileXcodeRuns: Bool = false,
        restartsSimulatorService: Bool = false
    ) {
        self.id = id
        self.targets = targets
        self.operation = operation
        self.risk = risk
        self.isEnabledByDefault = isEnabledByDefault
        self.isBlockedWhileXcodeRuns = isBlockedWhileXcodeRuns
        self.restartsSimulatorService = restartsSimulatorService
    }

}

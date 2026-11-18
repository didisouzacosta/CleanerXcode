//
//  CleanerWindowSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 09/11/26.
//

/// The window's single sheet: the cleanup confirmation (R5, F31) or "Support CleanerXcode" (C31).
/// They never show together, and a confirmation always wins.
enum CleanerWindowSheet: Identifiable, Hashable {

    // MARK: - Cases

    case confirmation
    case support

    // MARK: - Public Properties

    var id: Self {
        self
    }

    // MARK: - Public Methods

    static func resolve(phase: CleanerPhase, isShowingSupportSheet: Bool) -> CleanerWindowSheet? {
        if case .confirming = phase {
            return .confirmation
        }

        return isShowingSupportSheet ? .support : nil
    }

}

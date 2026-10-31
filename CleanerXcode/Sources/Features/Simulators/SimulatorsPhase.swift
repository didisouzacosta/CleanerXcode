//
//  SimulatorsPhase.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The Simulators section (plan section 2.4). It stays `idle` until the section is expanded.
enum SimulatorsPhase: Equatable {

    // MARK: - Cases

    case idle
    case loading
    case loaded
    case empty
    case toolsUnavailable
    case failed(CleanupError)
    /// The UDIDs or the runtime identifier being deleted.
    case deleting(Set<String>)

    // MARK: - Public Properties

    var isDeleting: Bool {
        if case .deleting = self {
            true
        } else {
            false
        }
    }

}

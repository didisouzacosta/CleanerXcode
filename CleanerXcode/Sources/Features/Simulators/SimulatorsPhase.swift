//
//  SimulatorsPhase.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The "Simulators and runtimes" lists (plan section 2.4). It stays `idle` until the window first
/// activates or the page opens.
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

    /// The lists are on screen, even while something is being deleted.
    var showsLists: Bool {
        switch self {
        case .loaded, .deleting: true
        default: false
        }
    }

    var isDeleting: Bool {
        if case .deleting = self {
            true
        } else {
            false
        }
    }

}

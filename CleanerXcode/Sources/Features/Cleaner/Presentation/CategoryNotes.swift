//
//  CategoryNotes.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import Foundation

extension CategoryRowState.UnavailableReason {

    // MARK: - Public Properties

    /// Why the row cannot be cleaned right now.
    var note: LocalizedStringResource {
        switch self {
        case .toolsUnavailable: "Needs the Xcode tools"
        case .xcodeIsRunning: "Close Xcode to clean"
        case .simulatorListUnavailable: "The simulator list could not be read"
        }
    }

}

extension CleanupRestrictions.Warning {

    // MARK: - Public Properties

    /// Why the item needs a confirmation (R5), in the list and in the confirmation sheet.
    var note: LocalizedStringResource {
        switch self {
        case .xcodeIsRunning: "Xcode is open: items in use will be skipped"
        case .simulatorsWillClose: "The open simulators will be shut down"
        }
    }

}

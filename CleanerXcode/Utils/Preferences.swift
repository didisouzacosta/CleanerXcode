//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class Preferences {
    
    static let shared = Preferences()
    
    var canRemoveArchives = StoragedValue(
        Shell.Command.removeArchives.rawValue,
        defaultValue: true
    )
    
    var canRemoveCaches = StoragedValue(
        Shell.Command.removeCaches.rawValue,
        defaultValue: true
    )
    
    var canRemoveDerivedData = StoragedValue(
        Shell.Command.removeDerivedData.rawValue,
        defaultValue: true
    )
    
    var canClearDeviceSupport = StoragedValue(
        Shell.Command.clearDeviceSupport.rawValue,
        defaultValue: false
    )
    
    var canRemoveOldSimulators = StoragedValue(
        Shell.Command.removeOldSimulators.rawValue,
        defaultValue: false
    )
    
    var canClearSimultorData = StoragedValue(
        Shell.Command.clearSimulatorData.rawValue,
        defaultValue: false
    )
    
    var canResertXcodePreferences = StoragedValue(
        Shell.Command.resetXcodePreferences.rawValue,
        defaultValue: false
    )
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}

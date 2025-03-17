//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class Preferences {
    
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
    
    var canRemoveDeviceSupport = StoragedValue(
        Shell.Command.removeDeviceSupport.rawValue,
        defaultValue: false
    )
    
    var canRemoveOldSimulators = StoragedValue(
        Shell.Command.removeOldSimulators.rawValue,
        defaultValue: false
    )
    
    var canRemoveSimultorData = StoragedValue(
        Shell.Command.removeSimulatorData.rawValue,
        defaultValue: true
    )
    
    var canResertXcode = StoragedValue(
        Shell.Command.resetXcode.rawValue,
        defaultValue: false
    )
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}

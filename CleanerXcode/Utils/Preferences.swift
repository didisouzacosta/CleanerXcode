//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class Preferences {
    
    var canRemoveDerivedData = StoragedValue(
        ShellScript.Command.removeDerivedData.rawValue,
        defaultValue: true
    )
    
    var canRemoveCaches = StoragedValue(
        ShellScript.Command.removeCaches.rawValue,
        defaultValue: true
    )
    
    var canRemoveDeviceSupport = StoragedValue(
        ShellScript.Command.removeDeviceSupport.rawValue,
        defaultValue: false
    )
    
    var canRemoveOldSimulators = StoragedValue(
        ShellScript.Command.removeOldSimulators.rawValue,
        defaultValue: false
    )
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}

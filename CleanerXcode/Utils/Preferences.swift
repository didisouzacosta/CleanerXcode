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
    
    var removeArchives = StoragedValue(
        Command.removeArchives.script,
        defaultValue: true
    )
    
    var removeCaches = StoragedValue(
        Command.removeCaches.script,
        defaultValue: true
    )
    
    var removeDerivedData = StoragedValue(
        Command.removeDerivedData.script,
        defaultValue: true
    )
    
    var clearDeviceSupport = StoragedValue(
        Command.clearDeviceSupport.script,
        defaultValue: false
    )
    
    var removeOldSimulators = StoragedValue(
        Command.removeOldSimulators.script,
        defaultValue: false
    )
    
    var clearSimulatorData = StoragedValue(
        Command.clearSimulatorData.script,
        defaultValue: false
    )
    
    var resetXcodePreferences = StoragedValue(
        Command.resetXcodePreferences.script,
        defaultValue: false
    )
    
    var displayFreeUpSpaceInMenuBar = StoragedValue(
        "display-free-up-space-in-menu-bar",
        defaultValue: true
    )
    
    var launchAtLogin = StoragedValue(
        "launch-at-login",
        defaultValue: true
    )
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}

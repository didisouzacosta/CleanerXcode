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
        Command.removeArchives.script,
        defaultValue: true
    )
    
    var canRemoveCaches = StoragedValue(
        Command.removeCaches.script,
        defaultValue: true
    )
    
    var canRemoveDerivedData = StoragedValue(
        Command.removeDerivedData.script,
        defaultValue: true
    )
    
    var canClearDeviceSupport = StoragedValue(
        Command.clearDeviceSupport.script,
        defaultValue: false
    )
    
    var canRemoveOldSimulators = StoragedValue(
        Command.removeOldSimulators.script,
        defaultValue: false
    )
    
    var canClearSimultorData = StoragedValue(
        Command.clearSimulatorData.script,
        defaultValue: false
    )
    
    var canResertXcodePreferences = StoragedValue(
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

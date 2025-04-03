//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@Observable
final class Preferences {
    
    // MARK: - Public Variables
    
    static let shared = Preferences()
    
    var removeArchives: StoragedValue<Bool>
    var removeCaches: StoragedValue<Bool>
    var removeDerivedData: StoragedValue<Bool>
    var clearDeviceSupport: StoragedValue<Bool>
    var removeOldSimulators: StoragedValue<Bool>
    var clearSimulatorData: StoragedValue<Bool>
    var resetXcodePreferences: StoragedValue<Bool>
    var displayFreeUpSpaceInMenuBar: StoragedValue<Bool>
    var launchAtLogin: StoragedValue<Bool>
    
    // MARK: - Private Variables
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initializers
    
    init(_ userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        removeArchives = .init(
            Command.removeArchives.script,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        removeCaches = .init(
            Command.removeCaches.script,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        removeDerivedData = StoragedValue(
            Command.removeDerivedData.script,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        clearDeviceSupport = StoragedValue(
            Command.clearDeviceSupport.script,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        removeOldSimulators = StoragedValue(
            Command.removeOldSimulators.script,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        clearSimulatorData = StoragedValue(
            Command.clearSimulatorData.script,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        resetXcodePreferences = StoragedValue(
            Command.resetXcodePreferences.script,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        displayFreeUpSpaceInMenuBar = StoragedValue(
            "display-free-up-space-in-menu-bar",
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        launchAtLogin = StoragedValue(
            "launch-at-login",
            defaultValue: true,
            userDefaults: userDefaults
        )
    }
    
}

extension EnvironmentValues {
    
    @Entry var preferences = Preferences()
    
}

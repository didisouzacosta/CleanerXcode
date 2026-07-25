//
//  Preferences.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 13/03/25.
//

import SwiftUI

@MainActor
@Observable
final class Preferences {
    
    // MARK: - Public Variables
    
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
            CleanupAction.removeArchives.id,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        removeCaches = .init(
            CleanupAction.removeCaches.id,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        removeDerivedData = StoragedValue(
            CleanupAction.removeDerivedData.id,
            defaultValue: true,
            userDefaults: userDefaults
        )
        
        clearDeviceSupport = StoragedValue(
            CleanupAction.clearDeviceSupport.id,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        removeOldSimulators = StoragedValue(
            CleanupAction.removeOldSimulators.id,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        clearSimulatorData = StoragedValue(
            CleanupAction.clearSimulatorData.id,
            defaultValue: false,
            userDefaults: userDefaults
        )
        
        resetXcodePreferences = StoragedValue(
            CleanupAction.resetXcodePreferences.id,
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

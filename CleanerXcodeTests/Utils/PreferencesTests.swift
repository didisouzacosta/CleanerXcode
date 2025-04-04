//
//  PreferencesTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Testing
import Foundation

@testable import CleanerXcode

struct PreferencesTests {

    private let preferences = Preferences(.test)
    
    init() {
        UserDefaults.test.reset()
    }
    
    @Test
    func ensureRemoveArchivesPreferenceConsistency() async throws {
        #expect(preferences.removeArchives.key == "remove-archives")
        #expect(preferences.removeArchives.value == true)
    }
    
    @Test
    func ensureRemoveCachesPreferenceConsistency() async throws {
        #expect(preferences.removeCaches.key == "remove-caches")
        #expect(preferences.removeCaches.value == true)
    }
    
    @Test
    func ensureRemoveDerivedDataPreferenceConsistency() async throws {
        #expect(preferences.removeDerivedData.key == "remove-derived-data")
        #expect(preferences.removeDerivedData.value == true)
    }
    
    @Test
    func ensureClearDeviceSupportPreferenceConsistency() async throws {
        #expect(preferences.clearDeviceSupport.key == "clear-device-support")
        #expect(preferences.clearDeviceSupport.value == false)
    }
    
    @Test
    func ensureRemoveOldSimulatorsPreferenceConsistency() async throws {
        #expect(preferences.removeOldSimulators.key == "remove-old-simulators")
        #expect(preferences.removeOldSimulators.value == false)
    }
    
    @Test
    func ensureClearSimulatorDataPreferenceConsistency() async throws {
        #expect(preferences.clearSimulatorData.key == "clear-simulator-data")
        #expect(preferences.clearSimulatorData.value == false)
    }
    
    @Test
    func ensureResetXcodePreferencePreferenceConsistency() async throws {
        #expect(preferences.resetXcodePreferences.key == "reset-xcode-preferences")
        #expect(preferences.resetXcodePreferences.value == false)
    }
    
    @Test
    func ensureDisplayFreeUpSpaceInMenuBarPreferenceConsistency() async throws {
        #expect(preferences.displayFreeUpSpaceInMenuBar.key == "display-free-up-space-in-menu-bar")
        #expect(preferences.removeArchives.value == true)
    }
    
    @Test
    func ensureLaunchAtLoginPreferenceConsistency() async throws {
        #expect(preferences.launchAtLogin.key == "launch-at-login")
        #expect(preferences.removeArchives.value == true)
    }

}

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

    private let preferences = Preferences()
    
    @Test func ensureRemoveArchivesPreferenceKeyConsistency() async throws {
        #expect(preferences.removeArchives.key == "remove-archives")
    }
    
    @Test func ensureRemoveCachesPreferenceKeyConsistency() async throws {
        #expect(preferences.removeCaches.key == "remove-caches")
    }
    
    @Test func ensureRemoveDerivedDataPreferenceKeyConsistency() async throws {
        #expect(preferences.removeDerivedData.key == "remove-derived-data")
    }
    
    @Test func ensureClearDeviceSupportPreferenceKeyConsistency() async throws {
        #expect(preferences.clearDeviceSupport.key == "clear-device-support")
    }
    
    @Test func ensureRemoveOldSimulatorsPreferenceKeyConsistency() async throws {
        #expect(preferences.removeOldSimulators.key == "remove-old-simulators")
    }
    
    @Test func ensureClearSimulatorDataPreferenceKeyConsistency() async throws {
        #expect(preferences.clearSimulatorData.key == "clear-simulator-data")
    }
    
    @Test func ensureResetXcodePreferencePreferenceKeyConsistency() async throws {
        #expect(preferences.resetXcodePreferences.key == "reset-xcode-preferences")
    }
    
    @Test func ensureDisplayFreeUpSpaceInMenuBarPreferenceKeyConsistency() async throws {
        #expect(preferences.displayFreeUpSpaceInMenuBar.key == "display-free-up-space-in-menu-bar")
    }
    
    @Test func ensureLaunchAtLoginPreferenceKeyConsistency() async throws {
        #expect(preferences.launchAtLogin.key == "launch-at-login")
    }

}

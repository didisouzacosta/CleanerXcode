//
//  PreferencesTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 03/04/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct PreferencesTests {

    // MARK: - Private Variables

    private let preferences = Preferences(.test)

    // MARK: - Initializer

    init() {
        UserDefaults.test.reset()
    }

    // MARK: - Public Methods

    @Test
    func ensureRemoveArchivesPreferenceConsistency() throws {
        #expect(preferences.removeArchives.key == "remove-archives")
        #expect(preferences.removeArchives.value == true)
    }

    @Test
    func ensureRemoveCachesPreferenceConsistency() throws {
        #expect(preferences.removeCaches.key == "remove-caches")
        #expect(preferences.removeCaches.value == true)
    }

    @Test
    func ensureRemoveDerivedDataPreferenceConsistency() throws {
        #expect(preferences.removeDerivedData.key == "remove-derived-data")
        #expect(preferences.removeDerivedData.value == true)
    }

    @Test
    func ensureClearDeviceSupportPreferenceConsistency() throws {
        #expect(preferences.clearDeviceSupport.key == "clear-device-support")
        #expect(preferences.clearDeviceSupport.value == false)
    }

    @Test
    func ensureRemoveOldSimulatorsPreferenceConsistency() throws {
        #expect(preferences.removeOldSimulators.key == "remove-old-simulators")
        #expect(preferences.removeOldSimulators.value == false)
    }

    @Test
    func ensureClearSimulatorDataPreferenceConsistency() throws {
        #expect(preferences.clearSimulatorData.key == "clear-simulator-data")
        #expect(preferences.clearSimulatorData.value == false)
    }

    @Test
    func ensureResetXcodePreferencePreferenceConsistency() throws {
        #expect(preferences.resetXcodePreferences.key == "reset-xcode-preferences")
        #expect(preferences.resetXcodePreferences.value == false)
    }

    @Test
    func ensureDisplayFreeUpSpaceInMenuBarPreferenceConsistency() throws {
        #expect(preferences.displayFreeUpSpaceInMenuBar.key == "display-free-up-space-in-menu-bar")
        #expect(preferences.removeArchives.value == true)
    }

    @Test
    func ensureLaunchAtLoginPreferenceConsistency() throws {
        #expect(preferences.launchAtLogin.key == "launch-at-login")
        #expect(preferences.removeArchives.value == true)
    }

    @Test
    func ensureSendAnonymousAnalyticsPreferenceConsistency() {
        #expect(preferences.sendAnonymousAnalytics.key == "send-anonymous-analytics")
        #expect(preferences.sendAnonymousAnalytics.value == true)
    }

}

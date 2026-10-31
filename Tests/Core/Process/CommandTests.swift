//
//  CommandTests.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/03/25.
//

import Foundation
import Testing
@testable import CleanerXcode

struct CommandTests {

    // MARK: - Public Methods

    @Test
    func ensureCalculareFreeUpSpaceCommand() throws {
        #expect(assert(.calculateFreeUpSpace, script: "calculate-free-up-space"))
    }

    @Test
    func ensureClearDeviceSupportCommand() throws {
        #expect(assert(.clearDeviceSupport, script: "clear-device-support"))
    }

    @Test
    func ensureClearSimulatorDataCommand() throws {
        #expect(assert(.clearSimulatorData, script: "clear-simulator-data"))
    }

    @Test
    func ensureRemoveArchivesCommand() throws {
        #expect(assert(.removeArchives, script: "remove-archives"))
    }

    @Test
    func ensureRemoveCachesCommand() throws {
        #expect(assert(.removeCaches, script: "remove-caches"))
    }

    @Test
    func ensureRemoveDerivedDataCommand() throws {
        #expect(assert(.removeDerivedData, script: "remove-derived-data"))
    }

    @Test
    func ensureRemoveOldSimulatorsCommand() throws {
        #expect(assert(.removeOldSimulators, script: "remove-old-simulators"))
    }

    @Test
    func ensureResetXcodePreferencesCommand() throws {
        #expect(assert(.resetXcodePreferences, script: "reset-xcode-preferences"))
    }

    // MARK: - Private Methods

    private func assert(
        _ command: Command,
        script: String,
        bundle: Bundle = .main
    ) -> Bool {
        [
            command.id == script,
            command.script == script,
            command.path?.contains(script) == true,
            command.bundle == bundle,
        ].allSatisfy { $0 }
    }

}

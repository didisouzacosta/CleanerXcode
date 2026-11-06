//
//  PowerConditionsTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation
import Testing
@testable import CleanerXcode

/// Low Power Mode or a hot Mac skip the periodic background measurements (C40).
struct PowerConditionsTests {

    // MARK: - Public Methods

    @Test(arguments: [ProcessInfo.ThermalState.nominal, .fair])
    func aCoolMacOnNormalPowerIsNotConstrained(state: ProcessInfo.ThermalState) {
        #expect(!PowerConditions.isConstrained(isLowPowerModeEnabled: false, thermalState: state))
    }

    @Test(arguments: [ProcessInfo.ThermalState.serious, .critical])
    func aHotMacIsConstrained(state: ProcessInfo.ThermalState) {
        #expect(PowerConditions.isConstrained(isLowPowerModeEnabled: false, thermalState: state))
    }

    @Test
    func lowPowerModeIsConstrained() {
        #expect(PowerConditions.isConstrained(isLowPowerModeEnabled: true, thermalState: .nominal))
    }

}

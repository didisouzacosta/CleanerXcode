//
//  PowerConditions.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 05/11/26.
//

import Foundation

/// Whether the Mac asks apps to hold back: Low Power Mode or a serious or critical thermal state
/// (C40). `ProcessInfo` is safe to read from any thread.
nonisolated enum PowerConditions {

    // MARK: - Public Methods

    static func isConstrained(isLowPowerModeEnabled: Bool, thermalState: ProcessInfo.ThermalState) -> Bool {
        // `ThermalState` is not `Comparable`, so the hot states are listed.
        isLowPowerModeEnabled || [.serious, .critical].contains(thermalState)
    }

    static func current(_ processInfo: ProcessInfo = .processInfo) -> Bool {
        isConstrained(
            isLowPowerModeEnabled: processInfo.isLowPowerModeEnabled,
            thermalState: processInfo.thermalState
        )
    }

}

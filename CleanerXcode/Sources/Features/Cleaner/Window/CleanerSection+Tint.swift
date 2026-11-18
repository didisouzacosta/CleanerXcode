//
//  CleanerSection+Tint.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The colour of each section in the space bar, its legend and the overview cards (Figma page 08).
extension CleanerSection {

    // MARK: - Public Properties

    var tint: Color {
        switch self {
        case .xcode: .blue
        case .simulators: .purple
        case .temporary: .teal
        case .userData: .orange
        }
    }

}

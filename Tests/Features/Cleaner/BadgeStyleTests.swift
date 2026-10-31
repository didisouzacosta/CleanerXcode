//
//  BadgeStyleTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI
import Testing
@testable import CleanerXcode

/// Increase Contrast adds an edge instead of a stronger fill, which would bring the tinted text
/// closer to its background (N4).
struct BadgeStyleTests {

    // MARK: - Public Methods

    @Test
    func increaseContrastAddsABorderAndKeepsTheFill() {
        #expect(BadgeStyle.fillOpacity == 0.15)
        #expect(BadgeStyle.showsBorder(.increased))
        #expect(!BadgeStyle.showsBorder(.standard))
    }

}

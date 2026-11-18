//
//  SubtleMotionTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 31/10/26.
//

import Testing
@testable import CleanerXcode

/// Every change is animated subtly; with Reduce Motion nothing slides or scales (N4).
struct SubtleMotionTests {

    // MARK: - Public Methods

    @Test
    func animatesWithMotionByDefault() {
        let style = SubtleMotion(reducesMotion: false)

        #expect(style.isAnimated)
        #expect(style.transitionKind == .fadeAndSettle)
    }

    @Test
    func reduceMotionDropsTheMovement() {
        let style = SubtleMotion(reducesMotion: true)

        #expect(!style.isAnimated, "Layout changes happen at once, without sliding.")
        #expect(style.transitionKind == .fade)
    }

}

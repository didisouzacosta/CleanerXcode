//
//  CategoryRowStateTests.swift
//  CleanerXcodeTests
//
//  Created by Adriano Costa on 05/11/26.
//

import Testing
@testable import CleanerXcode

/// A background measurement keeps each row's last value until the new one arrives (C40), so the
/// menu bar label never drops and climbs back.
struct CategoryRowStateTests {

    // MARK: - Public Methods

    @Test(arguments: [
        CategoryRowState.measured(4_000),
        .empty,
        .failed(.permissionDenied),
    ])
    func aBackgroundMeasurementKeepsTheLastValue(current: CategoryRowState) {
        #expect(CategoryRowState.refreshed(current: current, planned: .measuring, keepingValues: true) == current)
    }

    @Test(arguments: [
        CategoryRowState.measured(4_000),
        .empty,
        .failed(.permissionDenied),
    ])
    func aNormalMeasurementShowsMeasuringAgain(current: CategoryRowState) {
        #expect(CategoryRowState.refreshed(current: current, planned: .measuring, keepingValues: false) == .measuring)
    }

    /// What is known before reading the disk applies at once, even in the background.
    @Test
    func aPlannedStateOtherThanMeasuringAlwaysWins() {
        let unavailable = CategoryRowState.unavailable(.xcodeIsRunning)

        #expect(CategoryRowState
            .refreshed(current: .measured(1), planned: unavailable, keepingValues: true) == unavailable)
        #expect(CategoryRowState.refreshed(current: .measured(1), planned: .empty, keepingValues: true) == .empty)
    }

    @Test
    func withoutALastValueTheRowIsMeasured() {
        #expect(CategoryRowState.refreshed(current: nil, planned: .measuring, keepingValues: true) == .measuring)
        #expect(CategoryRowState.refreshed(current: .measuring, planned: .measuring, keepingValues: true) == .measuring)
        #expect(
            CategoryRowState.refreshed(
                current: .unavailable(.toolsUnavailable),
                planned: .measuring,
                keepingValues: true
            ) == .measuring
        )
    }

    @Test
    func onlyAnUnavailableRowIsUnavailable() {
        #expect(CategoryRowState.unavailable(.xcodeIsRunning).isUnavailable)
        #expect(CategoryRowState.unavailable(.toolsUnavailable).isUnavailable)
        #expect(!CategoryRowState.measured(1).isUnavailable)
        #expect(!CategoryRowState.measuring.isUnavailable)
        #expect(!CategoryRowState.empty.isUnavailable)
        #expect(!CategoryRowState.failed(.permissionDenied).isUnavailable)
    }

}

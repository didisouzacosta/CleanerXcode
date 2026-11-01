//
//  OverviewSummaryCard.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The top of the overview (Figma page 08): the phase, the total, its detail and either a progress
/// bar or the space by section. A plain card: the actions live in the action bar.
struct OverviewSummaryCard: View {

    // MARK: - Public Properties

    let hero: HeroContent
    let breakdown: SpaceBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let symbol = hero.symbol {
                Image(systemName: symbol.name)
                    .font(.title2)
                    .foregroundStyle(symbol.tint.color)
                    .padding(.bottom, 4)
                    .accessibilityHidden(true)
                    .subtleTransition()
            }

            Text(hero.eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            AmountView(hero: hero)

            Text(verbatim: hero.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            IndicatorView(indicator: hero.indicator, breakdown: breakdown)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Palette.card, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }

}

private struct AmountView: View {

    // MARK: - Public Properties

    let hero: HeroContent

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(hero.amount)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(hero.isAmountDimmed ? .tertiary : .primary)
                // The amount follows the cleanup item by item; the layout only animates when the
                // phase changes.
                .subtleAnimation(value: hero.amount)
                .monospacedDigit()
                .contentTransition(.numericText())

            if hero.isFreedAmount {
                Text("freed")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .subtleTransition()
            }
        }
        .accessibilityElement(children: .combine)
    }

}

private struct IndicatorView: View {

    // MARK: - Public Properties

    let indicator: HeroContent.Indicator
    let breakdown: SpaceBreakdown

    var body: some View {
        switch indicator {
        case .none:
            EmptyView()

        case let .progress(value):
            ProgressView(value: value)
                .subtleAnimation(value: value)
                .subtleTransition()

        case .breakdown:
            SpaceBreakdownBar(breakdown: breakdown)
                .subtleTransition()
        }
    }

}

#if DEBUG
    #Preview("Ready") {
        OverviewSummaryCard(
            hero: HeroContent(
                phase: .ready,
                totalBytes: 35_800_000_000,
                foundBytes: 87_700_000_000,
                measuredCategoryCount: 15,
                categoryCount: 15
            ),
            breakdown: SpaceBreakdown(bytesBySection: [.xcode: 31_300_000_000, .simulators: 4_500_000_000])
        )
        .padding()
        .frame(width: 668)
        .background(Palette.window)
    }

    #Preview("Measuring") {
        OverviewSummaryCard(
            hero: HeroContent(
                phase: .measuring(first: true),
                totalBytes: 0,
                foundBytes: 0,
                measuredCategoryCount: 9,
                categoryCount: 15
            ),
            breakdown: SpaceBreakdown(bytesBySection: [:])
        )
        .padding()
        .frame(width: 668)
        .background(Palette.window)
    }
#endif

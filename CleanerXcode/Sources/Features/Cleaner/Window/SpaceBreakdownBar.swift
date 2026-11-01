//
//  SpaceBreakdownBar.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The space each section would free (Figma page 08): proportional capsules and a legend with
/// every section. VoiceOver reads it as one element.
struct SpaceBreakdownBar: View {

    // MARK: - Public Properties

    let breakdown: SpaceBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Capsule()
                    .fill(.quaternary)
                    .opacity(breakdown.segments.isEmpty ? 1 : 0)

                ProportionalWidthLayout(spacing: 2) {
                    ForEach(breakdown.segments) { segment in
                        Capsule()
                            .fill(segment.section.tint)
                            .proportionalWidth(segment.fraction)
                    }
                }
            }
            .frame(height: 10)

            HStack(spacing: 16) {
                ForEach(breakdown.legend) { item in
                    LegendLabel(item: item)
                }
            }
            .font(.caption)
            .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Space by section"))
        .accessibilityValue(Text(verbatim: spokenLegend))
    }

    // MARK: - Private Properties

    private var spokenLegend: String {
        breakdown.legend
            .map { "\(String(localized: $0.section.shortTitle)) \($0.bytes.formatted(.byteCount(style: .file)))" }
            .joined(separator: ", ")
    }

}

private struct LegendLabel: View {

    // MARK: - Public Properties

    let item: SpaceBreakdown.LegendItem

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(item.section.tint)
                .frame(width: 7, height: 7)

            Text(item.section.shortTitle)

            Text(item.bytes.formatted(.byteCount(style: .file)))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

}

#if DEBUG
    #Preview("Two sections") {
        SpaceBreakdownBar(breakdown: SpaceBreakdown(bytesBySection: [
            .xcode: 31_300_000_000,
            .simulators: 4_500_000_000,
        ]))
        .padding()
        .frame(width: 628)
    }

    #Preview("Nothing selected") {
        SpaceBreakdownBar(breakdown: SpaceBreakdown(bytesBySection: [:]))
            .padding()
            .frame(width: 628)
    }
#endif

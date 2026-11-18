//
//  SpaceBreakdown.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

/// The space bar of the overview (Figma page 08): what each section would free with the current
/// selection, as proportional segments and a legend with every section.
struct SpaceBreakdown: Equatable {

    // MARK: - Public Properties

    let segments: [Segment]
    let legend: [LegendItem]
    let totalBytes: Int64

    // MARK: - Initializers

    init(bytesBySection: [CleanerSection: Int64]) {
        let legend = CleanerSection.allCases.map { LegendItem(section: $0, bytes: max(bytesBySection[$0] ?? 0, 0)) }
        let total = legend.reduce(0) { $0 + $1.bytes }

        self.legend = legend
        self.totalBytes = total
        self.segments = legend
            .filter { $0.bytes > 0 }
            .map { Segment(section: $0.section, bytes: $0.bytes, fraction: Double($0.bytes) / Double(total)) }
    }

    /// Only the selected categories with a measured size count, like the estimated total.
    init(
        groups: [CleanerSection.Group],
        selectedIDs: Set<CleanupCategoryID>,
        rows: [CleanupCategoryID: CategoryRowState]
    ) {
        var bytes: [CleanerSection: Int64] = [:]

        for group in groups {
            bytes[group.section] = group.categories.reduce(0) { total, category in
                guard selectedIDs.contains(category.id), case let .measured(size) = rows[category.id] else {
                    return total
                }

                return total + size
            }
        }

        self.init(bytesBySection: bytes)
    }

    // MARK: - Nested Types

    struct Segment: Equatable, Identifiable {

        // MARK: - Public Properties

        let section: CleanerSection
        let bytes: Int64
        let fraction: Double

        var id: CleanerSection {
            section
        }

    }

    struct LegendItem: Equatable, Identifiable {

        // MARK: - Public Properties

        let section: CleanerSection
        let bytes: Int64

        var id: CleanerSection {
            section
        }

    }

}

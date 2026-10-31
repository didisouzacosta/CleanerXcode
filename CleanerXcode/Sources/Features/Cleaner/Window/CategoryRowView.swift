//
//  CategoryRowView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// One category: checkbox, symbol, title and explanation, risk badge and size. Every row has the
/// same height (owner adjustment to C01).
struct CategoryRowView: View {

    // MARK: - Public Properties

    let category: CleanupCategory
    let viewModel: CleanerViewModel

    var body: some View {
        let presentation = CategoryPresentation(category.id)

        Toggle(isOn: isSelected) {
            HStack(spacing: 10) {
                Image(systemName: isBlocked ? "lock.fill" : presentation.systemImage)
                    .frame(width: 20)
                    .foregroundStyle(isBlocked ? .orange : .secondary)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.title)
                        .lineLimit(1)

                    note(presentation)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 8)

                if let risk = RiskBadge(risk: category.risk) {
                    risk
                }

                Text(valueText)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(hasFailed ? .red : .secondary)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
        .toggleStyle(.checkbox)
        .disabled(!viewModel.canToggle(category.id))
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
        .accessibilityValue(Text(valueText))
    }

    // MARK: - Private Properties

    private var row: CategoryRowState? {
        viewModel.rows[category.id]
    }

    private var isBlocked: Bool {
        row == .unavailable(.xcodeIsRunning)
    }

    private var isSelected: Binding<Bool> {
        Binding {
            viewModel.selectedIDs.contains(category.id)
        } set: { _ in
            viewModel.toggle(category.id)
        }
    }

    private var failedItemCount: Int {
        viewModel.phase.report?.failedResults.count { $0.categoryID == category.id } ?? 0
    }

    private var hasFailed: Bool {
        failedItemCount > 0
    }

    private var valueText: LocalizedStringResource {
        if case let .cleaning(progress) = viewModel.phase, progress.currentCategory == category.id {
            return "Cleaning…"
        }

        if hasFailed {
            return "Failed"
        }

        // Resetting the preferences frees no space, so it has no size.
        if case .resetPreferences = category.operation {
            return "—"
        }

        switch row {
        case .measuring, nil: return "Measuring…"
        case let .measured(bytes): return "\(bytes.formatted(.byteCount(style: .file)))"
        case .empty: return "\(Int64.zero.formatted(.byteCount(style: .file)))"
        case .unavailable, .failed: return "—"
        }
    }

    // MARK: - Private Methods

    /// The explanation, or what keeps the category from being cleaned right now.
    @ViewBuilder
    private func note(_ presentation: CategoryPresentation) -> some View {
        if hasFailed {
            Text("\(failedItemCount) items could not be removed")
                .foregroundStyle(.red)
        } else if case let .unavailable(reason) = row {
            Text(reason.note)
                .foregroundStyle(.orange)
        } else if case let .failed(error) = row {
            Text(error.summary)
                .foregroundStyle(.orange)
        } else if let warning = viewModel.restrictions.warnings[category.id] {
            Text(warning.note)
                .foregroundStyle(.orange)
        } else if category.id == .clearTemporaryFiles {
            // The fixed notice of the temporary folder (R13), with the age from Settings.
            Text(
                "Close AI apps and terminals first · items newer than \(viewModel.minimumTemporaryAgeInDays) days are kept"
            )
            .foregroundStyle(.secondary)
        } else {
            Text(presentation.subtitle)
                .foregroundStyle(.secondary)
        }
    }

}

/// "Attention" in orange and "Dangerous" in red; safe items have none.
struct RiskBadge: View {

    // MARK: - Public Properties

    let title: LocalizedStringResource
    let tint: Color

    var body: some View {
        Text(title)
            .font(.caption2.weight(.medium))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15), in: .capsule)
    }

    // MARK: - Initializers

    init?(risk: RiskLevel) {
        switch risk {
        case .safe:
            return nil

        case .attention:
            title = "Attention"
            tint = .orange

        case .dangerous:
            title = "Dangerous"
            tint = .red
        }
    }

}

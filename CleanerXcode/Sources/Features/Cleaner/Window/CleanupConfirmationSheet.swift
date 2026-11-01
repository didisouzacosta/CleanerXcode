//
//  CleanupConfirmationSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// Asks before a plan with attention or danger, or one that closes open apps (R5, F31): what
/// happens to each item, where it goes, and a destructive confirmation.
struct CleanupConfirmationSheet: View {

    // MARK: - Public Properties

    let viewModel: CleanerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Confirm cleanup", systemImage: "exclamationmark.triangle")
                .font(.title2.weight(.semibold))
                .labelStyle(ConfirmationTitleStyle())

            Text(introduction)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(listedCategories) { category in
                    ConfirmationRow(
                        category: category,
                        warning: viewModel.restrictions.warnings[category.id],
                        size: size(of: category.id)
                    )
                }
            }
            .padding(12)
            .background(.background.secondary, in: .rect(cornerRadius: 12))

            footnote

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    viewModel.cancel()
                }
                .keyboardShortcut(.cancelAction)

                Button(role: .destructive) {
                    Task { await viewModel.confirm() }
                } label: {
                    Text(confirmTitle)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Private Properties

    /// Empty while the sheet animates away after the confirmation.
    private var plan: CleanupPlan? {
        if case let .confirming(plan) = viewModel.phase {
            plan
        } else {
            nil
        }
    }

    /// The items with risk or a warning; safe items run without comment.
    private var listedCategories: [CleanupCategory] {
        (plan?.categories ?? []).filter { $0.risk != .safe || viewModel.restrictions.warnings[$0.id] != nil }
    }

    /// Some plans only ask because an app is open.
    private var introduction: LocalizedStringResource {
        ConfirmationIntro(risks: listedCategories.map(\.risk)).text
    }

    private var confirmTitle: LocalizedStringResource {
        viewModel.totalBytes > 0 ? "Clean \(viewModel.totalBytes.formatted(.byteCount(style: .file)))" : "Clean"
    }

    @ViewBuilder
    private var footnote: some View {
        let goesToTrash = plan?.categories.contains { $0.operation == .removeContents(.trash) } ?? false
        let closesSimulators = listedCategories
            .contains { viewModel.restrictions.warnings[$0.id] == .simulatorsWillClose }

        if goesToTrash || closesSimulators {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    if goesToTrash {
                        Text("Items in the Trash only free space after you empty it.")
                    }

                    if closesSimulators {
                        Text("The open simulators will be shut down.")
                    }
                }
            } icon: {
                Image(systemName: "info.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Private Methods

    /// The measured size of an item, next to where it goes.
    private func size(of id: CleanupCategoryID) -> String? {
        guard case let .measured(bytes) = viewModel.rows[id] else { return nil }

        return bytes.formatted(.byteCount(style: .file))
    }

}

private struct ConfirmationRow: View {

    // MARK: - Public Properties

    let category: CleanupCategory
    let warning: CleanupRestrictions.Warning?
    let size: String?

    var body: some View {
        let presentation = CategoryPresentation(category.id)

        HStack(spacing: 10) {
            Image(systemName: presentation.systemImage)
                .frame(width: 20)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(presentation.title)
                    .font(.body.weight(.semibold))

                Text(presentation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let warning {
                    Text(warning.note)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 8)

            if let badge = RiskBadge(risk: category.risk) {
                badge
            }

            Text(destination)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.quaternary, in: .rect(cornerRadius: 6))

            if let size {
                Text(verbatim: size)
                    .font(.body)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 52, alignment: .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Private Properties

    private var destination: LocalizedStringResource {
        switch category.operation {
        case .removeContents(.trash): "Trash"
        case .resetPreferences: "Reset"
        default: "Permanent"
        }
    }

}

/// The warning symbol in red next to the title.
private struct ConfirmationTitleStyle: LabelStyle {

    // MARK: - Public Methods

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .foregroundStyle(.red)

            configuration.title
        }
    }

}

#if DEBUG
    #Preview("Danger") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .confirming)

        CleanupConfirmationSheet(viewModel: viewModel)
            .task { await CleanerWindowPreview.prepare(viewModel, for: .confirming) }
    }

    #Preview("Xcode open") {
        @Previewable @State var viewModel = CleanerWindowPreview.makeViewModel(for: .confirmingWhileXcodeIsOpen)

        CleanupConfirmationSheet(viewModel: viewModel)
            .task { await CleanerWindowPreview.prepare(viewModel, for: .confirmingWhileXcodeIsOpen) }
    }
#endif

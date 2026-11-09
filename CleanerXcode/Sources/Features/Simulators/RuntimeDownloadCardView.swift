//
//  RuntimeDownloadCardView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import SwiftUI

/// The runtime download card of the "Simulators and runtimes" page (C30, plan section 5), in the
/// style of the page's status card. Purely visual: the page passes the presentation and actions.
/// With a known percentage, a bar sits between the title and the caption (C34); otherwise a spinner
/// sits next to the button.
struct RuntimeDownloadCardView: View {

    // MARK: - Public Properties

    let presentation: RuntimeDownloadPresentation
    /// Choose and Try again wait during a cleanup or a deletion; Cancel never does.
    let isActionDisabled: Bool
    let disabledHelp: LocalizedStringResource?
    let onChoose: () -> Void
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.systemImage)
                .font(.body)
                .foregroundStyle(iconStyle)
                .frame(width: 20)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: presentation.title)
                    .contentTransition(.numericText())

                if case let .determinate(fraction, valueDescription) = presentation.indicator {
                    ProgressView(value: fraction)
                        .progressViewStyle(.linear)
                        .controlSize(.small)
                        .padding(.vertical, 3)
                        .accessibilityLabel(Text("Download progress"))
                        .accessibilityValue(Text(verbatim: valueDescription))
                        .subtleTransition()
                }

                Text(verbatim: presentation.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 18)

            HStack(spacing: 8) {
                if case let .indeterminate(label) = presentation.indicator {
                    ProgressView()
                        .controlSize(.small)
                        .accessibilityLabel(Text(verbatim: label))
                }

                if let action = presentation.action {
                    Button(action.title) {
                        perform(action)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isDisabled(action))
                    .help(help(for: action))
                }
            }
        }
        .frame(minHeight: 52)
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Palette.card, in: .rect(cornerRadius: 12))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Private Properties

    private var iconStyle: AnyShapeStyle {
        switch presentation.tint {
        case .secondary: AnyShapeStyle(.secondary)
        case .accent: AnyShapeStyle(.tint)
        case .green: AnyShapeStyle(.green)
        case .orange: AnyShapeStyle(.orange)
        }
    }

    // MARK: - Private Methods

    private func perform(_ action: RuntimeDownloadPresentation.Action) {
        switch action {
        case .choose:
            onChoose()

        case .retry:
            onRetry()

        case .cancel:
            onCancel()
        }
    }

    private func isDisabled(_ action: RuntimeDownloadPresentation.Action) -> Bool {
        action != .cancel && isActionDisabled
    }

    private func help(for action: RuntimeDownloadPresentation.Action) -> Text {
        guard isDisabled(action), let disabledHelp else { return Text(verbatim: "") }

        return Text(disabledHelp)
    }

}

#if DEBUG
    #Preview("Idle") {
        RuntimeDownloadCardPreview(.idle)
    }

    #Preview("Downloading one") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.downloadingOne)
    }

    #Preview("Queue, 2 of 3") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.queue)
    }

    #Preview("One installed") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.oneInstalled)
    }

    #Preview("All installed") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.allInstalled)
    }

    #Preview("One failed") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.oneFailed)
    }

    #Preview("Partly failed") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.partlyFailed)
    }

    #Preview("Cancelled") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.cancelled)
    }

    #Preview("Cancelled after an install") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.cancelledAfterInstalling)
    }

    #Preview("Choose disabled during a cleanup") {
        RuntimeDownloadCardPreview(.idle, isActionDisabled: true)
    }

    #Preview("Queue during a cleanup") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.queue, isActionDisabled: true)
    }

    #Preview("Queue, dark") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.queue)
            .preferredColorScheme(.dark)
    }

    #Preview("Downloading 3%") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingOne,
            progress: RuntimeDownloadPreviewFixtures.threePercent
        )
    }

    #Preview("Downloading 42%, about 12 min") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingOne,
            progress: RuntimeDownloadPreviewFixtures.fortyTwoPercent
        )
    }

    #Preview("Downloading 7%, about 1 h 20 min") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingOne,
            progress: RuntimeDownloadPreviewFixtures.sevenPercent
        )
    }

    #Preview("Installing") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingOne,
            progress: RuntimeDownloadPreviewFixtures.installing
        )
    }

    #Preview("Queue 2 of 3 with progress") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.queue,
            progress: RuntimeDownloadPreviewFixtures.fortyTwoPercent
        )
    }

    #Preview("Updating the list") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.updatingList)
    }

    #Preview("Queue, updating the list") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.queueUpdatingList)
    }

    #Preview("iOS 26.5, downloading 42%, about 12 min") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingEarlierVersion,
            progress: RuntimeDownloadPreviewFixtures.fortyTwoPercent
        )
    }

    #Preview("iOS 26.5 not available for the selected Xcode") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.earlierVersionUnavailable)
    }

    #Preview("iOS 26.5 not available, dark") {
        RuntimeDownloadCardPreview(RuntimeDownloadPreviewFixtures.earlierVersionUnavailable)
            .preferredColorScheme(.dark)
    }

    #Preview("Downloading 42%, dark") {
        RuntimeDownloadCardPreview(
            RuntimeDownloadPreviewFixtures.downloadingOne,
            progress: RuntimeDownloadPreviewFixtures.fortyTwoPercent
        )
        .preferredColorScheme(.dark)
    }
#endif

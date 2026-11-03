//
//  RuntimeDownloadSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import SwiftUI

/// The "Download runtimes" sheet (C30, A1, Figma 47:1911): the four platforms with what is installed
/// for each, nothing selected when it opens, and a queue that downloads one at a time.
struct RuntimeDownloadSheet: View {

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    /// A cleanup started from the menu bar panel while the sheet is open disables the download.
    let isLocked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Download runtimes")
                    .font(.title2.weight(.semibold))
            }

            Text(message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(content.rows) { row in
                    RuntimeDownloadPlatformRow(row: row, isSelected: isSelected(row))
                }
            }
            .padding(.vertical, 4)
            .background(.background.secondary, in: .rect(cornerRadius: 12))

            Label {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Text(verbatim: content.selectionSummary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)

                Spacer()

                Button("Cancel", role: .cancel, action: viewModel.cancelRuntimeDownloadChoice)
                    .keyboardShortcut(.cancelAction)

                Button(action: confirm) {
                    Text(content.confirmTitle)
                        .contentTransition(.opacity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(!content.isConfirmEnabled || isBusy)
                .help(confirmHelp)
            }
        }
        .padding(24)
        .frame(width: 460)
        .subtleAnimation(value: choice)
    }

    // MARK: - Private Properties

    private var message: LocalizedStringResource {
        """
        Choose the platforms. CleanerXcode downloads the runtime that matches the selected Xcode, one at a \
        time. Each one is several GB.
        """
    }

    private var note: LocalizedStringResource {
        """
        The download goes on if you leave this page. Keep CleanerXcode open until it finishes; you can \
        cancel at any time.
        """
    }

    private var choice: RuntimeDownloadChoice {
        viewModel.downloadChoice ?? RuntimeDownloadChoice()
    }

    private var content: RuntimeDownloadSheetContent {
        RuntimeDownloadSheetContent(choice: choice, runtimes: viewModel.runtimes)
    }

    private var isBusy: Bool {
        isLocked || viewModel.phase.isDeleting
    }

    private var confirmHelp: Text {
        if isLocked {
            Text("Available when the cleanup ends")
        } else if viewModel.phase.isDeleting {
            Text("Wait while simulators or a runtime are deleted.")
        } else {
            Text(verbatim: "")
        }
    }

    // MARK: - Private Methods

    private func isSelected(_ row: RuntimeDownloadSheetContent.Row) -> Binding<Bool> {
        Binding {
            row.isSelected
        } set: { _ in
            viewModel.toggleRuntimePlatform(row.platform)
        }
    }

    private func confirm() {
        Task { await viewModel.confirmRuntimeDownload() }
    }

}

/// One platform: checkbox, symbol, name and what is installed, centered on one vertical axis (Figma
/// 47:1911). A checkbox with a label aligns to the label's first line, so the native checkbox has
/// its label hidden and sits in a centered row; the rest of the row is a plain button that toggles
/// it, so the whole row stays clickable. Only the checkbox is exposed to VoiceOver: the platform
/// name is its label, what is installed its hint, and its on/off value stays its own.
private struct RuntimeDownloadPlatformRow: View {

    // MARK: - Public Properties

    let row: RuntimeDownloadSheetContent.Row
    let isSelected: Binding<Bool>

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Toggle(isOn: isSelected) {
                Text(verbatim: row.platform.rawValue)
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .accessibilityHint(Text(verbatim: row.installedDetail))

            Button(action: toggle) {
                HStack(alignment: .center, spacing: 10) {
                    // A fixed frame for every symbol: the iPhone glyph is taller than the TV one.
                    Image(systemName: row.systemImage)
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                        .frame(width: 24, height: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: row.platform.rawValue)
                            .font(.body.weight(.semibold))

                        Text(verbatim: row.installedDetail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 12)
    }

    // MARK: - Private Methods

    private func toggle() {
        isSelected.wrappedValue.toggle()
    }

}

#if DEBUG
    #Preview("Nothing selected") {
        RuntimeDownloadSheetPreview([])
    }

    #Preview("Two selected") {
        RuntimeDownloadSheetPreview([.watchOS, .visionOS])
    }

    #Preview("Download disabled during a cleanup") {
        RuntimeDownloadSheetPreview([.watchOS, .visionOS], isLocked: true)
    }

    #Preview("Two selected, dark") {
        RuntimeDownloadSheetPreview([.watchOS, .visionOS])
            .preferredColorScheme(.dark)
    }
#endif

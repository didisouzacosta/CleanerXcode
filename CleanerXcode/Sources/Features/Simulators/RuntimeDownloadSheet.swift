//
//  RuntimeDownloadSheet.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 01/11/26.
//

import SwiftUI

/// The "Download runtimes" sheet (C30, A1, Figma 47:1911): the four platforms with what is installed
/// for each, nothing selected when it opens, and a queue that downloads one at a time. Each platform
/// has a menu of versions, the selected Xcode's first (C35, Figma 92:7540): the sheet opens at once
/// and loads the earlier versions while it is open; closing it cancels the load.
struct RuntimeDownloadSheet: View {

    // MARK: - States

    /// "Try again" loads the versions again by changing the task's id.
    @State private var retryCount = 0

    // MARK: - Public Properties

    let viewModel: SimulatorsViewModel
    /// A cleanup started from the menu bar panel while the sheet is open disables the download.
    let isLocked: Bool

    var body: some View {
        // Built once per update: each platform's menu is derived from the versions and the runtimes.
        let content = self.content

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("Download runtimes")
                    .font(.title2.weight(.semibold))
            }

            Text(content.message)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 0) {
                ForEach(content.rows) { row in
                    RuntimeDownloadPlatformRow(
                        row: row,
                        isSelected: isSelected(row),
                        selectedOptionID: selectedOptionID(row)
                    )
                }
            }
            .padding(.vertical, 4)
            .background(.background.secondary, in: .rect(cornerRadius: 12))

            if let versionsNote = content.versionsNote {
                RuntimeVersionsNoteView(note: versionsNote, retry: retry)
                    .subtleTransition()
            }

            VStack(alignment: .leading, spacing: 8) {
                RuntimeDownloadNoteLabel(text: note)

                if content.showsEarlierVersionNote {
                    RuntimeDownloadNoteLabel(text: RuntimeDownloadSheetContent.earlierVersionNote)
                        .subtleTransition()
                }
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
        .frame(width: 520)
        .subtleAnimation(value: choice)
        .subtleAnimation(value: content.versionsNote)
        .task(id: retryCount) {
            await viewModel.runtimeVersions.load()
        }
    }

    // MARK: - Private Properties

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
        RuntimeDownloadSheetContent(
            choice: choice,
            runtimes: viewModel.runtimes,
            versions: viewModel.runtimeVersions.snapshot,
            isLoadingVersions: viewModel.runtimeVersions.isLoading
        )
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

    /// Choosing a version, Xcode's included, also checks the platform.
    private func selectedOptionID(_ row: RuntimeDownloadSheetContent.Row) -> Binding<String> {
        Binding {
            row.selectedOption.id
        } set: { id in
            guard let option = row.options.first(where: { $0.id == id }) else { return }

            viewModel.selectRuntimeVersion(option.version, for: row.platform)
        }
    }

    private func retry() {
        retryCount += 1
    }

    private func confirm() {
        Task { await viewModel.confirmRuntimeDownload() }
    }

}

/// The note while the versions load (a small spinner), or when they are unavailable (with "Try
/// again"), below the list of platforms (C35, Figma 92:8552 and 92:8892).
private struct RuntimeVersionsNoteView: View {

    // MARK: - Public Properties

    let note: RuntimeDownloadSheetContent.VersionsNote
    let retry: () -> Void

    var body: some View {
        switch note {
        case .loading:
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)

                Text(note.text)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .accessibilityElement(children: .combine)

        case .unavailable:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                RuntimeDownloadNoteLabel(text: note.text, systemImage: "exclamationmark.circle")

                Spacer(minLength: 0)

                Button("Try again", action: retry)
                    .buttonStyle(.link)
                    .font(.caption)
            }
        }
    }

}

/// A secondary note with its symbol, as the sheet's other notes.
private struct RuntimeDownloadNoteLabel: View {

    // MARK: - Public Properties

    let text: LocalizedStringResource

    var systemImage = "info.circle"

    var body: some View {
        Label {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
        }
    }

}

#if DEBUG
    #Preview("Nothing selected") {
        RuntimeDownloadSheetPreview([])
    }

    #Preview("Two selected") {
        RuntimeDownloadSheetPreview([.watchOS, .visionOS])
    }

    #Preview("iOS 26.5 and watchOS selected") {
        RuntimeDownloadSheetPreview([.watchOS], versions: [.iOS: "26.5"])
    }

    #Preview("Loading the versions") {
        RuntimeDownloadSheetPreview([], source: .neverFinishes)
    }

    #Preview("Versions unavailable") {
        RuntimeDownloadSheetPreview([], source: .unavailable)
    }

    #Preview("Download disabled during a cleanup") {
        RuntimeDownloadSheetPreview([.watchOS], versions: [.iOS: "26.5"], isLocked: true)
    }

    #Preview("iOS 26.5 and watchOS selected, dark") {
        RuntimeDownloadSheetPreview([.watchOS], versions: [.iOS: "26.5"])
            .preferredColorScheme(.dark)
    }

    #Preview("Two selected, dark") {
        RuntimeDownloadSheetPreview([.watchOS, .visionOS])
            .preferredColorScheme(.dark)
    }
#endif

//
//  MenuBarPanelView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// The menu bar panel (flow 2.3, item 6; Figma page 05): the total, the main action, Settings,
/// "Open CleanerXcode" and Quit. A plan that needs a confirmation opens the main window, which
/// shows it; the panel never asks on its own.
struct MenuBarPanelView: View {

    // MARK: - Environments

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openURL) private var openURL

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    /// Simulators or a runtime are being deleted: nothing starts a cleanup meanwhile (C21).
    let isDeletingSimulators: Bool

    var body: some View {
        let content = HeroContent(viewModel: viewModel)

        VStack(spacing: 10) {
            Text(content.eyebrow)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(content.amount)
                    .font(.system(.title, weight: .bold))
                    .monospacedDigit()

                if content.isFreedAmount {
                    Text("freed")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            if let progress = content.progress {
                ProgressView(value: progress)
            }

            Text(detail(content))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let action = content.actions.first {
                primaryButton(action)
            }

            footer
        }
        .padding(16)
        .frame(width: 300)
        .task {
            // Opening the panel measures again only past the debounce and the cache (R1).
            await viewModel.windowDidActivate()
        }
    }

    // MARK: - Private Properties

    private var reviewsInWindow: Bool {
        viewModel.phase == .ready && viewModel.cleanNeedsConfirmation
    }

    private var footer: some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("Settings")

            Spacer()

            Button("Open CleanerXcode", action: openMainWindow)
                .buttonStyle(.link)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .labelStyle(.iconOnly)
            }
            .help("Quit CleanerXcode")
        }
        .buttonStyle(.glass)
    }

    // MARK: - Private Methods

    private func detail(_ content: HeroContent) -> String {
        let action = content.actions.first
        let detail = MenuBarPresentation.panelDetail(
            action: action?.kind,
            isEnabled: action?.isEnabled ?? false,
            isDeletingSimulators: isDeletingSimulators,
            reviewsInWindow: reviewsInWindow
        )

        switch detail {
        case .content:
            return content.detail

        case .waitForSimulators:
            return String(localized: "Wait while simulators or a runtime are deleted.")

        case .reviewInWindow:
            return String(localized: "Some selected items need a confirmation. It opens in the main window.")
        }
    }

    @ViewBuilder
    private func primaryButton(_ action: HeroContent.Action) -> some View {
        let title: LocalizedStringResource = reviewsInWindow ? "Review and clean…" : action.title
        let button = Button {
            perform(action.kind)
        } label: {
            Text(title)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.large)
        .disabled(!action.isEnabled || !MenuBarPresentation.isEnabled(
            action.kind,
            isDeletingSimulators: isDeletingSimulators
        ))

        if action.style == .destructive {
            button
                .buttonStyle(.glassProminent)
                .tint(.red)
        } else {
            button.buttonStyle(.glassProminent)
        }
    }

    private func perform(_ kind: HeroContent.Action.Kind) {
        switch kind {
        case .clean:
            if reviewsInWindow {
                openMainWindow()
            }

            Task {
                await viewModel.requestClean()
                openMainWindowIfConfirming()
            }

        case .cancel:
            viewModel.cancel()

        case .dismiss:
            viewModel.dismissReport()

        case .retry:
            Task {
                await viewModel.retryFailed()
                openMainWindowIfConfirming()
            }

        case .toggleDetails:
            openMainWindow()

        case .openPrivacySettings:
            openURL(HeroContent.fullDiskAccessURL)
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApplication.shared.activate()
    }

    /// An app may have opened since the last measurement, so the plan can still end up waiting
    /// for a confirmation; the main window shows it.
    private func openMainWindowIfConfirming() {
        if MenuBarPresentation.needsMainWindow(after: viewModel.phase) {
            openMainWindow()
        }
    }

}

/// The icon and, when on, the size that can be freed.
struct MenuBarLabelView: View {

    // MARK: - Public Properties

    let viewModel: CleanerViewModel
    let showsSize: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image("iconClear")
                .accessibilityLabel(Text(verbatim: "CleanerXcode"))

            switch MenuBarPresentation.label(
                phase: viewModel.phase,
                totalBytes: viewModel.totalBytes,
                showsSize: showsSize
            ) {
            case let .size(bytes):
                Text(bytes.formatted(.byteCount(style: .file)))

            case .cleaning:
                Text("Cleaning…")

            case nil:
                EmptyView()
            }
        }
    }

}

#if DEBUG
    #Preview("Panel · ready") {
        MenuBarPanelPreview(.ready)
    }

    #Preview("Panel · measuring") {
        MenuBarPanelPreview(.measuring)
    }

    #Preview("Panel · review in the window") {
        MenuBarPanelPreview(.review)
    }

    #Preview("Panel · cleaning") {
        MenuBarPanelPreview(.cleaning)
    }

    #Preview("Panel · success") {
        MenuBarPanelPreview(.finished(.success))
    }

    #Preview("Panel · partial failure") {
        MenuBarPanelPreview(.finished(.partialFailure))
    }

    #Preview("Panel · permission denied") {
        MenuBarPanelPreview(.permissionDenied)
    }

    #Preview("Panel · deleting simulators") {
        MenuBarPanelPreview(.ready, isDeletingSimulators: true)
    }

    #Preview("Label") {
        MenuBarLabelPreview()
    }
#endif

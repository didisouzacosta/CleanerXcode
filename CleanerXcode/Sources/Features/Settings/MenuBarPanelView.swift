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
            if let symbol = symbol(content) {
                Image(systemName: symbol.name)
                    .font(.title3)
                    .foregroundStyle(symbol.color)
                    .accessibilityHidden(true)
                    .subtleTransition()
            }

            Text(MenuBarPresentation.eyebrow(phase: viewModel.phase) ?? content.eyebrow)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(content.amount)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(content.isAmountDimmed ? .tertiary : .primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .subtleAnimation(value: content.amount)

                if content.isFreedAmount {
                    Text("freed")
                        .foregroundStyle(.secondary)
                        .subtleTransition()
                }
            }
            .accessibilityElement(children: .combine)

            if let progress = content.progress {
                ProgressView(value: progress)
                    .subtleTransition()
            }

            if MenuBarPresentation.showsDetail(phase: viewModel.phase, detail: panelDetail(content)) {
                Text(detail(content))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentTransition(.opacity)
                    .subtleTransition()
            }

            if let action = content.actions.first {
                primaryButton(action)
            }

            footer(content)
        }
        .subtleAnimation(value: viewModel.phase.kind)
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

    // MARK: - Private Methods

    private func footer(_ content: HeroContent) -> some View {
        HStack {
            SettingsLink {
                Label("Settings", systemImage: "gearshape")
                    .labelStyle(.iconOnly)
            }
            .help("Settings")

            Spacer()

            Group {
                switch MenuBarPresentation.link(for: content.actions.map(\.kind)) {
                case .openApp:
                    Button("Open CleanerXcode", action: openMainWindow)
                case .seeDetails:
                    Button("See details", action: openMainWindow)
                }
            }
            .buttonStyle(.link)
            .font(.body.weight(.semibold))

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
        .buttonBorderShape(.circle)
        .controlSize(.large)
    }

    private func panelDetail(_ content: HeroContent) -> MenuBarPresentation.PanelDetail {
        let action = content.actions.first

        return MenuBarPresentation.panelDetail(
            action: action?.kind,
            isEnabled: action?.isEnabled ?? false,
            isDeletingSimulators: isDeletingSimulators,
            reviewsInWindow: reviewsInWindow
        )
    }

    /// The status of a finished run, or the warning of a plan that the window will confirm.
    private func symbol(_ content: HeroContent) -> (name: String, color: Color)? {
        if reviewsInWindow {
            return ("exclamationmark.triangle.fill", .orange)
        }

        return content.symbol.map { ($0.name, $0.tint.color) }
    }

    private func detail(_ content: HeroContent) -> String {
        switch panelDetail(content) {
        case .content:
            return content.detail

        case .waitForSimulators:
            return String(localized: "Wait while simulators or a runtime are deleted.")

        case .reviewInWindow:
            return String(localized: MenuBarPresentation.ReviewNote(risks: viewModel.plannedRisks).text)
        }
    }

    @ViewBuilder
    private func primaryButton(_ action: HeroContent.Action) -> some View {
        let title: LocalizedStringResource = reviewsInWindow ? "Review and clean…" : action.title
        let button = Button {
            perform(action.kind)
        } label: {
            Text(title)
                .font(.title3.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 28)
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
        openWindow(id: WindowID.main)
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

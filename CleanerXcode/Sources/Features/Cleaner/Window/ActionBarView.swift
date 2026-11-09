//
//  ActionBarView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The fixed bar at the bottom of the window (Figma page 08): the phase, the total and the
/// actions, with the main one on the right. Glass on the controls layer, its buttons in the same
/// `GlassEffectContainer`; the content scrolls underneath it (R41).
struct ActionBarView: View {

    // MARK: - Public Properties

    let content: ActionBarContent
    let onAction: (HeroContent.Action.Kind) -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                if let symbol = content.symbol {
                    Image(systemName: symbol.name)
                        .font(.title3)
                        .foregroundStyle(symbol.tint.color)
                        .accessibilityHidden(true)
                        .subtleTransition()
                }

                ActionBarSummary(content: content)

                Spacer(minLength: 12)

                ForEach(content.actions) { action in
                    ActionBarButton(action: action, shortcut: content.shortcut(for: action.kind)) {
                        onAction(action.kind)
                    }
                    .subtleTransition()
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 12)
            .frame(minHeight: 66)
            .glassSurface(cornerRadius: 24)
        }
        .accessibilityElement(children: .contain)
    }

}

private struct ActionBarSummary: View {

    // MARK: - Public Properties

    let content: ActionBarContent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.eyebrow)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .lineLimit(1)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(verbatim: content.amount)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(content.isAmountDimmed ? .tertiary : .primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .subtleAnimation(value: content.amount)

                suffix
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            if let progress = content.progress {
                ProgressView(value: progress)
                    .controlSize(.small)
                    .frame(width: 220)
                    .subtleAnimation(value: progress)
                    .subtleTransition()
            }
        }
        .fixedSize()
    }

    // MARK: - Private Properties

    private var suffix: Text {
        switch content.suffix {
        case .estimated: Text("estimated")
        case .freed: Text("freed")
        case nil: Text(verbatim: "")
        }
    }

}

private struct ActionBarButton: View {

    // MARK: - Public Properties

    let action: HeroContent.Action
    let shortcut: ActionBarContent.Shortcut?
    let perform: () -> Void

    var body: some View {
        let button = Button(action: perform) {
            label
        }
        .controlSize(.large)
        .keyboardShortcut(keyboardShortcut)
        .disabled(!action.isEnabled)

        switch action.style {
        case .prominent:
            button.buttonStyle(.glassProminent)

        case .destructive:
            button
                .buttonStyle(.glassProminent)
                .tint(.red)

        case .secondary:
            button.buttonStyle(.glass)

        case .support:
            button
                .buttonStyle(.glassProminent)
                .tint(Palette.support)

        case .plain:
            button
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Private Properties

    /// The glass buttons share one size; "Close" next to the donation suggestion is text only,
    /// and supporting the project carries a filled heart (C31, Figma 102:9568).
    @ViewBuilder
    private var label: some View {
        switch action.style {
        case .plain:
            Text(action.title)
                .font(.system(size: 13))
                .lineLimit(1)
                .padding(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
                .contentShape(.rect)

        case .support:
            Label {
                Text(action.title)
            } icon: {
                Image(systemName: "heart.fill")
                    .accessibilityHidden(true)
            }
            .font(.title3.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 16)
            .frame(minWidth: 150, minHeight: 30)

        case .prominent, .destructive, .secondary:
            Text(action.title)
                .font(.title3.weight(.semibold))
                .contentTransition(.opacity)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .frame(minWidth: 150, minHeight: 30)
        }
    }

    private var keyboardShortcut: KeyboardShortcut? {
        switch shortcut {
        case .cancel: .cancelAction
        case .default: .defaultAction
        case nil: nil
        }
    }

}

#if DEBUG
    #Preview("Ready") {
        ActionBarPreview(phase: .ready)
    }

    #Preview("Cleaning") {
        ActionBarPreview(phase: .cleaning(CleanupProgress(
            totalCategories: 5,
            startedCategories: 3,
            currentCategory: .removeDerivedData,
            freedBytes: 12_400_000_000
        )))
    }

    #Preview("Partial failure · details open") {
        ActionBarPreview(
            phase: .finished(CleanupReport(results: [
                CleanupItemResult(
                    categoryID: .removeCaches,
                    displayPath: "~/Caches",
                    bytes: 31_200_000_000,
                    outcome: .removed
                ),
                CleanupItemResult(
                    categoryID: .removeDerivedData,
                    displayPath: "~/DD",
                    bytes: 0,
                    outcome: .failed(.inUse)
                ),
            ])),
            isShowingDetails: true
        )
    }

    #Preview("Success · donation prompt") {
        ActionBarPreview(phase: .finished(CleanupReport(results: [
            CleanupItemResult(
                categoryID: .removeDerivedData,
                displayPath: "~/DD",
                bytes: 35_800_000_000,
                outcome: .removed
            ),
        ])), suggestsDonation: true)
    }

    #Preview("Reduce transparency") {
        ActionBarPreview(phase: .ready)
            .environment(\.reducesTransparencyOverride, true)
    }
#endif

//
//  CleanerHeroView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The total and the main action of each phase (plan section 2.4). Its actions sit together in a
/// `GlassEffectContainer`, and the card itself is glass unless Reduce Transparency is on.
struct CleanerHeroView: View {

    // MARK: - Environments

    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @Environment(\.reducesTransparencyOverride) private var reducesTransparencyOverride
    @Environment(\.openURL) private var openURL

    // MARK: - Bindings

    @Binding var isShowingFailures: Bool

    // MARK: - Public Properties

    let viewModel: CleanerViewModel

    var body: some View {
        let content = HeroContent(viewModel: viewModel)

        VStack(spacing: 4) {
            if let symbol = content.symbol {
                Image(systemName: symbol.name)
                    .font(.title2)
                    .foregroundStyle(symbol.tint.color)
                    .accessibilityHidden(true)
                    .subtleTransition()
            }

            Text(content.eyebrow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)

            amount(content)

            if let progress = content.progress {
                ProgressView(value: progress)
                    .padding(.horizontal, 24)
                    .subtleAnimation(value: progress)
                    .subtleTransition()
            }

            Text(content.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .contentTransition(.opacity)
                .multilineTextAlignment(.center)

            actions(content.actions)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(EdgeInsets(top: 24, leading: 24, bottom: 22, trailing: 24))
        .modifier(HeroBackground(reducesTransparency: reducesTransparency))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Private Properties

    private var reducesTransparency: Bool {
        reducesTransparencyOverride ?? systemReducesTransparency
    }

    // MARK: - Private Methods

    private func amount(_ content: HeroContent) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(content.amount)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(content.isAmountDimmed ? .tertiary : .primary)
                // The amount and the bar follow the cleanup item by item; the layout only animates
                // when the phase changes.
                .subtleAnimation(value: content.amount)
                .monospacedDigit()
                .contentTransition(.numericText())

            if content.isFreedAmount {
                Text("freed")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .subtleTransition()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func actions(_ actions: [HeroContent.Action]) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(actions) { action in
                    button(for: action)
                        .subtleTransition()
                }
            }
        }
    }

    @ViewBuilder
    private func button(for action: HeroContent.Action) -> some View {
        let button = Button {
            perform(action.kind)
        } label: {
            Text(action.title)
                .font(.title3.weight(.semibold))
                .contentTransition(.opacity)
                .padding(.horizontal, 22)
                .frame(minWidth: 144, minHeight: 30)
        }
        .controlSize(.large)
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
        }
    }

    private func perform(_ kind: HeroContent.Action.Kind) {
        switch kind {
        case .clean:
            Task { await viewModel.requestClean() }

        case .cancel:
            viewModel.cancel()

        case .dismiss:
            viewModel.dismissReport()

        case .retry:
            Task { await viewModel.retryFailed() }

        case .toggleDetails:
            isShowingFailures.toggle()

        case .openPrivacySettings:
            openURL(HeroContent.fullDiskAccessURL)
        }
    }

}

/// Glass on the controls layer; a solid surface when Reduce Transparency is on.
private struct HeroBackground: ViewModifier {

    // MARK: - Public Properties

    let reducesTransparency: Bool

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 22)

        if reducesTransparency {
            content.background(Palette.card, in: shape)
        } else {
            content
                .background(Palette.heroFill, in: shape)
                .overlay(shape.strokeBorder(Palette.heroEdge, lineWidth: 1))
                .glassEffect(.regular, in: shape)
                .shadow(color: .black.opacity(0.1), radius: 12, y: 8)
        }
    }

}

extension HeroContent.Symbol.Tint {

    var color: Color {
        switch self {
        case .success: .green
        case .attention: .orange
        case .failure: .red
        }
    }

}

extension EnvironmentValues {

    /// Lets previews show the Reduce Transparency variant; `nil` follows the system setting.
    @Entry var reducesTransparencyOverride: Bool?

}

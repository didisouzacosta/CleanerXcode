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

        VStack(spacing: 8) {
            if let symbol = content.symbol {
                Image(systemName: symbol.name)
                    .font(.title2)
                    .foregroundStyle(symbol.tint.color)
                    .accessibilityHidden(true)
            }

            Text(content.eyebrow)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            amount(content)

            if let progress = content.progress {
                ProgressView(value: progress)
                    .padding(.horizontal, 24)
            }

            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            actions(content.actions)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
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
                .font(.system(.largeTitle, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())

            if content.isFreedAmount {
                Text("freed")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func actions(_ actions: [HeroContent.Action]) -> some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(actions) { action in
                    button(for: action)
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
                .frame(minWidth: 140)
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
        if reducesTransparency {
            content.background(.background.secondary, in: .rect(cornerRadius: 24))
        } else {
            content.glassEffect(.regular, in: .rect(cornerRadius: 24))
        }
    }

}

private extension HeroContent.Symbol.Tint {

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

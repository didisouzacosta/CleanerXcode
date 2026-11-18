//
//  SubtleAnimation.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// Nothing on screen appears, disappears or changes abruptly (owner request, 2026-10-31): a short,
/// smooth animation for every change. With Reduce Motion nothing slides or scales (N4): layout
/// changes happen at once.
struct SubtleMotion {

    // MARK: - Public Properties

    let isAnimated: Bool
    let transitionKind: TransitionKind

    var animation: Animation? {
        isAnimated ? .smooth(duration: 0.3) : nil
    }

    var transition: AnyTransition {
        switch transitionKind {
        case .fadeAndSettle: .opacity.combined(with: .scale(scale: 0.98, anchor: .top))
        case .fade: .opacity
        }
    }

    // MARK: - Initializers

    init(reducesMotion: Bool) {
        isAnimated = !reducesMotion
        transitionKind = reducesMotion ? .fade : .fadeAndSettle
    }

    // MARK: - Nested Types

    enum TransitionKind: Equatable {
        case fadeAndSettle
        case fade
    }

}

private struct SubtleAnimation<Value: Equatable>: ViewModifier {

    // MARK: - Environments

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    // MARK: - Public Properties

    let value: Value

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        content.animation(SubtleMotion(reducesMotion: reducesMotion).animation, value: value)
    }

}

private struct SubtleTransition: ViewModifier {

    // MARK: - Environments

    @Environment(\.accessibilityReduceMotion) private var reducesMotion

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        content.transition(SubtleMotion(reducesMotion: reducesMotion).transition)
    }

}

extension View {

    // MARK: - Public Methods

    /// Animates every change caused by `value` subtly.
    func subtleAnimation(value: some Equatable) -> some View {
        modifier(SubtleAnimation(value: value))
    }

    /// What appears or leaves the screen does it gently: a fade with a slight settle, or only a
    /// fade with Reduce Motion.
    func subtleTransition() -> some View {
        modifier(SubtleTransition())
    }

}

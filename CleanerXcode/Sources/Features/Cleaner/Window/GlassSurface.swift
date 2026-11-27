//
//  GlassSurface.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// Glass on the controls layer, applied after the layout; a solid card with Reduce Transparency,
/// and a separator border with Increase Contrast (R38).
struct GlassSurface: ViewModifier {

    // MARK: - Environments

    @Environment(\.accessibilityReduceTransparency) private var systemReducesTransparency
    @Environment(\.reducesTransparencyOverride) private var reducesTransparencyOverride
    @Environment(\.colorSchemeContrast) private var contrast

    // MARK: - Public Properties

    let cornerRadius: CGFloat

    // MARK: - Private Properties

    private var reducesTransparency: Bool {
        reducesTransparencyOverride ?? systemReducesTransparency
    }

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)

        content
            .background(reducesTransparency ? Palette.card : .clear, in: shape)
            .overlay(shape.strokeBorder(.separator, lineWidth: contrast == .increased ? 1 : 0))
            .glassEffect(reducesTransparency ? .identity : .regular, in: shape)
    }

}

extension View {

    // MARK: - Public Methods

    func glassSurface(cornerRadius: CGFloat) -> some View {
        modifier(GlassSurface(cornerRadius: cornerRadius))
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

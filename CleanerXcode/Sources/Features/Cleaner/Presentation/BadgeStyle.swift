//
//  BadgeStyle.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import SwiftUI

/// The tinted badges and notices (N4). Increase Contrast adds an edge in the tint instead of a
/// stronger fill, which would bring the tinted text closer to its background.
enum BadgeStyle {

    // MARK: - Public Properties

    static let fillOpacity = 0.15

    // MARK: - Public Methods

    static func showsBorder(_ contrast: ColorSchemeContrast) -> Bool {
        contrast == .increased
    }

}

extension View {

    // MARK: - Public Methods

    /// The tinted fill, with an edge under Increase Contrast.
    func badgeBackground(_ tint: Color, in shape: some InsettableShape, contrast: ColorSchemeContrast) -> some View {
        background(tint.opacity(BadgeStyle.fillOpacity), in: shape)
            .overlay {
                if BadgeStyle.showsBorder(contrast) {
                    shape.strokeBorder(tint, lineWidth: 1)
                }
            }
    }

}

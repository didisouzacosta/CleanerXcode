//
//  Palette.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 31/10/26.
//

import AppKit
import SwiftUI

/// The surfaces of the approved layout (Figma pages 03 to 05), in light and dark: a grey window,
/// white list cards and the translucent hero.
enum Palette {

    // MARK: - Public Properties

    static let window = adaptive(light: NSColor(hex: 0xECECEE), dark: NSColor(hex: 0x1E1E20))
    static let card = adaptive(light: .white, dark: NSColor(hex: 0x2C2C2E))
    static let heroFill = adaptive(
        light: .white.withAlphaComponent(0.62),
        dark: NSColor(hex: 0x3A3A3E).withAlphaComponent(0.55)
    )
    static let heroEdge = adaptive(
        light: .white.withAlphaComponent(0.9),
        dark: .white.withAlphaComponent(0.16)
    )
    static let support = adaptive(light: NSColor(hex: 0xFF2D55), dark: NSColor(hex: 0xFF375F))

    // MARK: - Private Methods

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

}

private extension NSColor {

    // MARK: - Initializers

    convenience init(hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }

}

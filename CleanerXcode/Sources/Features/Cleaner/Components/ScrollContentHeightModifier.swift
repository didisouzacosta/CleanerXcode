//
//  ScrollContentHeightModifier.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 20/03/25.
//

import SwiftUI

struct ScrollContentHeightModifier: ViewModifier {

    // MARK: - Private Variables

    private let height: Binding<CGFloat>

    // MARK: - Initializers

    init(_ height: Binding<CGFloat>) {
        self.height = height
    }

    // MARK: - Public Methods

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentSize.height
            } action: { _, newValue in
                height.wrappedValue = newValue
            }
    }

}

extension View {

    func scrollContentHeight(_ height: Binding<CGFloat>) -> some View {
        modifier(ScrollContentHeightModifier(height))
    }

}

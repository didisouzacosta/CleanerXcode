//
//  ExpandableButton.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 28/03/25.
//

import SwiftUI

struct ExpandableButton<Label: View>: View {
    
    // MARK: - States
    
    @State private var isHover = false
    
    // MARK: - Public Variables
    
    var body: some View {
        Button {
            action()
        } label: {
            label()
                .clipped()
                .background {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(fill)
                        .scaleEffect(isHover ? 1.05 : 1)
                }
                .animation(.snappy, value: isHover)
        }
        .animation(.bouncy, value: isHover)
        .buttonStyle(.plain)
        .onHover { status in
            isHover = status
        }
    }
    
    // MARK: - Private Variables
    
    private let radius: CGFloat
    private let fill: Color
    private let action: () -> Void
    private let label: () -> Label
    
    private var opacity: CGFloat {
        isHover ? 0.1 : 0
    }
    
    // MARK: - Initializers
    
    init(
        radius: CGFloat = 8,
        fill: Color,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.radius = radius
        self.fill = fill
        self.action = action
        self.label = label
    }
    
}

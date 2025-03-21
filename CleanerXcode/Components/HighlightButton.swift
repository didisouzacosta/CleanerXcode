//
//  HighlightButton.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 20/03/25.
//

import SwiftUI

struct HighlightButton<Label: View>: View {
    
    // MARK: - States
    
    @State private var isHover = false
    
    // MARK: - Public Variables
    
    var body: some View {
        Button {
            action()
        } label: {
            label()
                .padding(.all, 4)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white.opacity(opacity))
                }
        }
        .buttonStyle(.plain)
        .animation(.snappy.speed(2), value: isHover)
        .onHover { status in
            isHover = status
        }
    }
    
    // MARK: - Private Variables
    
    private let action: () -> Void
    private let label: () -> Label
    
    private var opacity: CGFloat {
        isHover ? 0.1 : 0
    }
    
    // MARK: - Initializers
    
    init(
        _ action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.label = label
    }
    
}

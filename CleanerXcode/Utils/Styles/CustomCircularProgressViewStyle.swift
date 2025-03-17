//
//  CustomCircularProgressViewStyle.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 17/03/25.
//


import SwiftUI

struct CustomCircularProgressViewStyle: ProgressViewStyle {
    
    // MARK: Private Variables
    
    private let size: CGFloat
    
    // MARK: - Initializers
    
    init(size: CGFloat = 12) {
        self.size = size
    }
    
    // MARK: - Public Methods
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 3))
                .rotationEffect(.degrees(-90))
                .frame(width: size)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                .stroke(.white, style: StrokeStyle(lineWidth: 3))
                .rotationEffect(.degrees(-90))
                .frame(width: size)
        }
    }
    
}

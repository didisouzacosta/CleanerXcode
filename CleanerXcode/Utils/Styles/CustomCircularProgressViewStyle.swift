//
//  CustomCircularProgressViewStyle.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 17/03/25.
//

import SwiftUI

struct CustomCircularProgressViewStyle: ProgressViewStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 3))
                .rotationEffect(.degrees(-90))
            
            Circle()
                .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
    
}

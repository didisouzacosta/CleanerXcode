//
//  ValueState.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

enum ValueState<Value> {
    case idle
    case loading
    case success(Value)
    case failure(Error)
}

struct ValueStateView<Content: View, Value>: View {
    
    // MARK: - Public Variables
    
    var body: some View {
        ZStack {
            switch state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.small)
            case .success(let value):
                content(value)
            case .failure(let error):
                Text(error.localizedDescription)
            case .idle:
                EmptyView()
            }
        }
    }
    
    // MARK: - Private Variables
    
    private let state: ValueState<Value>
    private let content: (Value) -> Content
    
    // MARK: - Initializers
    
    init(
        _ state: ValueState<Value>,
        @ViewBuilder content: @escaping (Value) -> Content
    ) {
        self.state = state
        self.content = content
    }
    
}

//
//  HomeView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

struct HomeView: View {
    
    // MARK: - Environments
    
    @Environment(\.clearStore) private var clearStore
    
    // MARK: - States
    
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isShowPreferences = false
    
    private var test: Binding<Bool>
    
    init(_ test: Binding<Bool>) {
        self.test = test
    }
    
    // MARK: - Public Variables
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Cleaner Xcode")
                .font(.title2)
            
            Spacer(minLength: 22)
            
            Button {
                clean()
            } label: {
                Group {
                    if isLoading {
                        HStack(spacing: 0) {
                            ProgressView()
                                .scaleEffect(0.6)
                            Text("Cleaning...")
                        }
                        .transition(.move(edge: .leading))
                    } else if hasError {
                        Label("Try again!", image: "gobackward")
                            .transition(.move(edge: .trailing))
                    } else {
                        Label("Clean", image: "iconClear")
                            .transition(.move(edge: .trailing))
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .frame(height: 44)
                .font(.title3)
            }
            .background(hasError ? .red : .blue)
            .clipShape(RoundedRectangle(cornerRadius: 32))
            .disabled(isLoading)
            
            Spacer(minLength: 22)
            
            VStack(spacing: 8) {
                Divider()
                
                HStack {
                    Button {
                        test.wrappedValue.toggle()
                    } label: {
                        Image(systemName: "gear")
                            .resizable()
                            .frame(width: 16, height: 16)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                    
                    Text("Version \(NSApplication.fullVersion)")
                        .font(.footnote)
                        .foregroundStyle(.placeholder)
                    
                    Spacer()
                    
                    Button {
                        quit()
                    } label: {
                        HStack {
                            Text("Quit")
                            Text("\(Image(systemName: "command"))Q")
                                .foregroundStyle(.placeholder)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .animation(.easeIn, value: isLoading)
        .padding([.top, .leading, .trailing])
        .padding(.bottom, 12)
    }
    
    // MARK: - Private Variables
    
    private var hasError: Bool {
        error != nil
    }
    
    // MARK: - Private Methods
    
    private func quit() {
        clearStore.quit()
    }
    
    private func clean() {
        isLoading = true
        error = nil
        
        Task(priority: .background) {
            do {
                try await clearStore.clear()
            } catch {
                self.error = error
            }
            
            isLoading = false
        }
    }
    
}

#Preview {
    HomeView(.constant(false))
        .environment(\.clearStore, .init(.init()))
}

//
//  ContentView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI

struct ContentView: View {
    
    // MARK: - States
    
    @State private var isLoading = false
    @State private var error: Error?
    
    // MARK: - Public Variables
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Cleaner Xcode")
                .bold()
            
            VStack(spacing: 8) {
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
                }
                .background(hasError ? .red : .blue)
                .clipShape(RoundedRectangle(cornerRadius: 32))
                .disabled(isLoading)
                
                Menu {
                    Button(role: .destructive) {
                        terminate()
                    } label: {
                        Label("Close", systemImage: "xmark.circle")
                    }
                } label: {
                    Image(systemName: "gear")
                }
                .menuStyle(BorderlessButtonMenuStyle())
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .animation(.easeIn, value: isLoading)
            
            Text("Version \(NSApplication.fullVersion)")
                .font(.footnote)
                .foregroundStyle(.placeholder)
        }
        .frame(width: 160)
        .padding()
    }
    
    // MARK: - Private Variables
    
    private let shellScripCommander = ShellScriptCommander()
    
    private var hasError: Bool {
        error != nil
    }
    
    // MARK: - Private Methods
    
    private func terminate() {
        NSApplication.shared.terminate(nil)
    }
    
    private func clean() {
        isLoading = true
        error = nil
        
        Task(priority: .background) {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try await shellScripCommander.clean()
            } catch {
                self.error = error
            }
            
            isLoading = false
        }
    }
    
}

#Preview {
    ContentView()
}

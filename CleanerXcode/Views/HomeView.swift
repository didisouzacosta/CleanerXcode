//
//  HomeView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI
import Charts

struct HomeView: View {
    
    // MARK: - Environments
    
    @Environment(\.clearStore) private var clearStore
    @Environment(\.route) private var route
    
    // MARK: - States
    
    @State private var cleaning = false
    @State private var error: Error?
    @State private var isShowPreferences = false
    
    // MARK: - Public Variables
    
    var body: some View {
        VStack(spacing: 0) {
            header()
            Spacer(minLength: 22)
            buttonAction()
            Spacer(minLength: 22)
            footer()
        }
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
        guard !cleaning else { return }
        
        cleaning = true
        error = nil
        
        Task(priority: .background) {
            do {
                try await clearStore.clear()
            } catch {
                self.error = error
            }
            
            cleaning = false
        }
    }
    
    // MARK: - Components
    
    private func chart(_ steps: [Step]) -> some View {
        ProgressView(
            value: CGFloat(steps.count { $0.status != .waiting }),
            total: CGFloat(steps.count)
        )
        .progressViewStyle(.circular)
        .controlSize(.small)
    }
    
    private func buttonAction() -> some View {
        Button {
            clean()
        } label: {
            Group {
                if cleaning {
                    HStack {
                        chart(clearStore.steps)
                        Text("Cleaning...")
                    }
                    .foregroundStyle(.white)
                    .transition(.move(edge: .leading))
                } else if hasError {
                    Label("Try again!", image: "gobackward")
                        .transition(.move(edge: .leading))
                } else {
                    Label("Clean", image: "iconClear")
                        .transition(.move(edge: .trailing))
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .font(.title3)
            .animation(.bouncy, value: cleaning)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .background(hasError ? .red : cleaning ? .working : .blue)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .allowsHitTesting(!cleaning)
        .animation(.bouncy, value: cleaning)
    }
    
    private func header() -> some View {
        Text("Cleaner Xcode")
            .font(.title2)
    }
    
    private func footer() -> some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                Button {
                    route.isPresentSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .buttonStyle(.plain)
                .disabled(cleaning)
                
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
    
}

#Preview {
    HomeView()
        .environment(\.clearStore, .init(.init()))
        .environment(\.route, .init())
}

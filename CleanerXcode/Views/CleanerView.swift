//
//  CleanerView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 12/03/25.
//

import SwiftUI
import Charts

struct CleanerView: View {
    
    // MARK: - Environments
    
    @Environment(\.clearStore) private var clearStore
    @Environment(\.analytics) private var analytics
    @Environment(\.route) private var route
    @Environment(\.openURL) private var openURL
    
    // MARK: - States
    
    @State private var error: Error?
    @State private var isShowPreferences = false
    
    // MARK: - Public Variables
    
    var body: some View {
        VStack(spacing: 0) {
            header()
            Spacer(minLength: 22)
            VStack(spacing: 16) {
                buttonAction()
                social()
            }
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
        guard !clearStore.isCleaning else { return }
        
        error = nil
        
        Task(priority: .background) { @MainActor in
            do {
                try await clearStore.cleaner()
            } catch {
                self.error = error
            }
        }
    }
    
    // MARK: - Components
    
    private func progressView(_ steps: [Step]) -> some View {
        ProgressView(
            value: clearStore.clearProgress,
            total: clearStore.clearProgressTotal
        )
        .progressViewStyle(CustomCircularProgressViewStyle())
        .animation(.easeIn, value: clearStore.clearProgress)
    }
    
    private func header() -> some View {
        Text("Cleaner Xcode")
            .font(.title2)
    }
    
    private func buttonAction() -> some View {
        var allowsHitTesting: Bool {
            !clearStore.isCleaning || !clearStore.freeUpSpace.isZero
        }
        
        var backgroundColor: Color {
            hasError ? .red : clearStore.isCleaning ? .working : .blue
        }
        
        var buttonText: String {
            if clearStore.isCleaning {
                "Cleaning"
            } else if hasError {
                "Try again!"
            } else if clearStore.freeUpSpace.isZero {
                "Relax, all clear"
            } else {
                "Cleaner"
            }
        }
        
        @ViewBuilder
        func acessory() -> some View {
            if clearStore.isCleaning {
                progressView(clearStore.steps)
            } else if hasError {
                Image(systemName: "gobackward")
            } else {
                Image(.iconClear)
            }
        }
        
        return Button {
            clean()
        } label: {
            HStack {
                acessory()
                Text(buttonText)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .font(.title3)
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .allowsHitTesting(allowsHitTesting)
        .animation(.bouncy, value: clearStore.isCleaning)
    }
    
    private func social() -> some View {
        HStack(spacing: 16) {
            Button {
                openURL(.init(string: "https://github.com/didisouzacosta/CleanerXcode")!)
                analytics.log(.social(.github))
            } label: {
                Image("github.fill")
            }.buttonStyle(.plain)
            
            Button {
                openURL(.init(string: "https://x.com/didisouzacosta")!)
                analytics.log(.social(.x))
            } label: {
                Image("x")
            }.buttonStyle(.plain)
            
            Button {
                openURL(.init(string: "https://www.linkedin.com/in/adrianosouzacosta/")!)
                analytics.log(.social(.linkedin))
            } label: {
                Image("linkedin")
            }.buttonStyle(.plain)
        }
        .font(.system(size: 16))
        .foregroundStyle(.primary)
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
                .disabled(clearStore.isCleaning)
                
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
    CleanerView()
        .environment(\.clearStore, .init(.init(), analytics: Analytics()))
        .environment(\.route, .init())
}

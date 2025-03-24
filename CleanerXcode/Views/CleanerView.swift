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
    
    @State private var task: Task<Void, Error>?
    @State private var isShowPreferences = false
    
    // MARK: - Public Variables
    
    var body: some View {
        VStack(spacing: 0) {
            header()
            
            Spacer(minLength: 22)
            
            VStack(spacing: 16) {
                CleanerButton(
                    status: clearStore.cleanerStatus,
                    freeUpSpace: clearStore.freeUpSpace
                ) {
                    cleaner()
                }
                
                social()
            }
            
            Spacer(minLength: 22)
            
            footer()
        }
        .padding([.top, .leading, .trailing])
        .padding(.bottom, 12)
    }
    
    // MARK: - Private Methods
    
    private func quit() {
        clearStore.quit()
    }
    
    private func cleaner() {
        guard !clearStore.isCleaning else { return }
        
        task?.cancel()
        
        task = Task(priority: .background) { @MainActor in
            do {
                try await clearStore.cleaner()
            } catch {
                print(error)
            }
        }
    }
    
    // MARK: - Components
    
    private func header() -> some View {
        Text("Cleaner Xcode")
            .font(.title2)
    }
    
    private func social() -> some View {
        HStack(spacing: 16) {
            HighlightButton {
                openURL(.init(string: "https://github.com/didisouzacosta/CleanerXcode")!)
                analytics.log(.social(.github))
            } label: {
                Image("github.fill")
            }
            
            HighlightButton {
                openURL(.init(string: "https://x.com/didisouzacosta")!)
                analytics.log(.social(.x))
            } label: {
                Image("x")
            }
            
            HighlightButton {
                openURL(.init(string: "https://www.linkedin.com/in/adrianosouzacosta/")!)
                analytics.log(.social(.linkedin))
            } label: {
                Image("linkedin")
            }
        }
        .font(.system(size: 16))
        .foregroundStyle(.primary)
    }
    
    private func footer() -> some View {
        VStack(spacing: 8) {
            Divider()
            
            HStack {
                HighlightButton {
                    route.isPresentSettings.toggle()
                } label: {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .disabled(clearStore.isCleaning)
                
                Text("Version \(NSApplication.fullVersion)")
                    .font(.footnote)
                    .foregroundStyle(.placeholder)
                
                Spacer()
                
                HighlightButton {
                    quit()
                } label: {
                    HStack {
                        Text("Quit")
                        Text("\(Image(systemName: "command"))Q")
                            .foregroundStyle(.placeholder)
                    }
                }
            }
        }
    }
    
}

fileprivate struct CleanerButton: View {
    
    // MARK: - States
    
    @State private var isHover = false
    
    // MARK: - Private Variables
    
    private var backgroundColor: Color {
        switch status {
        case .idle: .blue
        case .completed, .cleaning: .cleaning
        case .error: .red
        }
    }

    private var text: LocalizedStringKey {
        switch status {
        case .cleaning: "Cleaning"
        case .error: "Try again"
        case .completed: "🎉 Success, all clear!"
        case .idle:
            if freeUpSpace.isZero {
                "Clear"
            } else {
                "Clear \(freeUpSpace.byteFormatter())"
            }
        }
    }
    
    private var allowsHitTesting: Bool {
        switch status {
        case .cleaning(_, _):
            false
        case .completed:
            false
        default:
            true
        }
    }
    
    // MARK: - Public Variables
    
    var body: some View {
        ZStack {
            Button {
                action()
            } label: {
                HStack {
                    switch status {
                    case .cleaning(let progress, let total):
                        ProgressView(
                            value: progress,
                            total: total
                        )
                        .progressViewStyle(CustomCircularProgressViewStyle())
                        .frame(width: 12, height: 12)
                    default:
                        EmptyView()
                    }
                    
                    Text(text)
                        .contentTransition(.numericText())
                }
                .font(.title2)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .clipped()
                .background {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(backgroundColor)
                        .scaleEffect(isHover && allowsHitTesting ? 1.05 : 1)
                }
                .animation(.snappy, value: status)
            }
            .allowsHitTesting(allowsHitTesting)
            .animation(.bouncy, value: isHover)
            .buttonStyle(.plain)
            .onHover { status in
                isHover = status
            }
        }
    }
    
    // MARK: - Private Variables
    
    private let action: () -> Void
    private let status: ClearStore.Status
    private let freeUpSpace: Double
    
    // MARK: - Initializers
    
    init(
        status: ClearStore.Status,
        freeUpSpace: Double,
        action: @escaping () -> Void
    ) {
        self.status = status
        self.freeUpSpace = freeUpSpace
        self.action = action
    }
    
}

#Preview {
    CleanerView()
        .environment(\.clearStore, .init(.init(), analytics: Analytics()))
        .environment(\.route, .init())
}

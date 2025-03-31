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
    @Environment(\.updateStore) private var updateStore
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
                openURL(Constants.githubURL)
                analytics.log(.social(.github))
            } label: {
                Image("github.fill")
            }
            
            HighlightButton {
                openURL(Constants.xURL)
                analytics.log(.social(.x))
            } label: {
                Image("x")
            }
            
            HighlightButton {
                openURL(Constants.linkedinURL)
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
                    route.path = .preferences
                } label: {
                    Image(systemName: "gear")
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                .disabled(clearStore.isCleaning)
                
                HStack(alignment: .center) {
                    Text("Version \(Bundle.main.fullVersion)")
                        .foregroundStyle(.placeholder)
                    
                    if updateStore.hasUpdate.value {
                        ExpandableButton(radius: 6, fill: .greenAction) {
                            if let url = updateStore.version?.downloadURL {
                                openURL(url)
                            }
                        } label: {
                            Text("Update")
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                    }
                }
                .font(.footnote)
                
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
    
    // MARK: - Private Variables
    
    private var fillColor: Color {
        switch status {
        case .idle: .blue
        case .completed, .cleaning: .greenAction
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
        ExpandableButton(radius: 32, fill: fillColor) {
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
        }
        .animation(.bouncy, value: status)
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
        .environment(\.updateStore, .init(Bundle.main))
        .environment(\.route, .init())
}




@Observable
final class ExamplePreviewableForm {
    
    var isEditing = false
    
}

struct ExamplePreviewableFormView: View {
    
    // MARK: - States
    
    @State private var form = ExamplePreviewableForm()
    
    // MARK: - Public Variables
    
    var body: some View {
        Form {
            
        }
        .disabled(isFormDisabled)
    }
    
    // MARK: - Private Variables
    
    private var isFormDisabled: Bool {
        !form.isEditing
    }
    
}

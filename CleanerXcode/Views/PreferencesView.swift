//
//  PreferencesView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI
import TipKit
import LaunchAtLogin

struct PreferencesView: View {
    
    // MARK: - Environments
    
    @Environment(\.cleanerStore) private var clearStore
    @Environment(\.preferences) private var preferences
    @Environment(\.route) private var route
    @Environment(\.openURL) private var openURL
    @Environment(\.analytics) private var analytics
    
    // MARK: - States
    
    @State private var contentHeight: CGFloat = 0
    
    // MARK: - Public Variables
    
    var body: some View {
        @Bindable var bindablePreferences = preferences
        
        VStack(alignment: .leading, spacing: 0) {
            HighlightButton {
                route.path = .cleaner
            } label: {
                Label("Home", systemImage: "chevron.backward")
            }
            .padding([.top, .trailing, .leading])

            Form {
                Section("Cache") {
                    factoryToggle(
                        "Remove Archives",
                        detail: clearStore.usedSpace.value.archives.byteFormatted(),
                        isOn: $bindablePreferences.removeArchives.value
                    )
                    
                    factoryToggle(
                        "Remove Caches",
                        detail: clearStore.usedSpace.value.cache.byteFormatted(),
                        isOn: $bindablePreferences.removeCaches.value
                    )
                    
                    factoryToggle(
                        "Remove Derived Data",
                        detail: clearStore.usedSpace.value.derivedData.byteFormatted(),
                        isOn: $bindablePreferences.removeDerivedData.value
                    )
                }
                
                Section("Simulators & Xcode") {
                    factoryToggle(
                        "Clear Device Support",
                        detail: clearStore.usedSpace.value.deviceSupport.byteFormatted(),
                        isOn: $bindablePreferences.clearDeviceSupport.value
                    )
                    
                    factoryToggle(
                        "Clear Simulator Data",
                        detail: clearStore.usedSpace.value.simulatorData.byteFormatted(),
                        isOn: $bindablePreferences.clearSimulatorData.value
                    )
                    
                    factoryToggle(
                        "Remove Old Simulators",
                        isOn: $bindablePreferences.removeOldSimulators.value
                    )
                    
                    factoryToggle(
                        "Reset Xcode Preferences",
                        isOn: $bindablePreferences.resetXcodePreferences.value
                    )
                }
                
                Section("Preferences") {
                    factoryToggle(
                        "Display Free Up Space In Menu Bar",
                        isOn: $bindablePreferences.displayFreeUpSpaceInMenuBar.value
                    )
                    
                    LaunchAtLogin.Toggle {
                        Text("Launch At Login")
                    } changedValue: { isOn in
                        preferences.launchAtLogin.value = isOn
                    }
                }
                
                Section("Dedication") {
                    Text("This simple app was made for anyone who loves developing for Apple technologies.\n\nI'd like to dedicate this app to my son Orlando and my wife Gisele.")
                }
                
                Section("Donate") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("If you like it tool, consider make a donation.")
                        
                        Button {
                            openURL(.init(string: "https://buy.stripe.com/00gcN772R2ns3wA9AA")!)
                            analytics.log(.donate)
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange)
                                .overlay {
                                    Text("Donate")
                                        .font(.body)
                                }
                                .frame(height: 32)
                        }.buttonStyle(.plain)
                    }
                }
            }
            .formStyle(.grouped)
            .frame(height: contentHeight)
            .animation(.bouncy, value: clearStore.freeUpSpace)
            .scrollContentHeight($contentHeight)
        }
    }
    
    // MARK: - Private Methods
    
    private func factoryToggle(
        _ text: LocalizedStringKey,
        @ViewBuilder accessory: () -> some View = { EmptyView() },
        detail: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center) {
            accessory()
            
            Text(text)
            
            Spacer()
            
            if let detail {
                Text(detail)
                    .contentTransition(.numericText())
                    .foregroundStyle(.placeholder)
            }
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
    
}

#Preview {
    PreferencesView()
        .environment(\.cleanerStore, .init(commandExecutor: Shell(), preferences: .init(), analytics: GoogleAnalytics()))
        .environment(\.preferences, .init())
        .environment(\.route, .init())
        .environment(\.analytics, .init())
}


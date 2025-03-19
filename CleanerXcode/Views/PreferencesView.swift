//
//  PreferencesView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

struct PreferencesView: View {
    
    // MARK: - Environments
    
    @Environment(\.clearStore) private var clearStore
    @Environment(\.preferences) private var preferences
    @Environment(\.route) private var route
    @Environment(\.openURL) private var openURL
    @Environment(\.analytics) private var analytics
    
    // MARK: - Public Variables
    
    var body: some View {
        @Bindable var bindablePreferences = preferences
        
        VStack(alignment: .leading, spacing: 0) {
            Button {
                route.isPresentSettings.toggle()
            } label: {
                Label("Home", systemImage: "chevron.backward")
            }
            .buttonStyle(.plain)
            .padding([.top, .trailing, .leading])
            .padding(.bottom, 8)

            Form {
                Section {
                    factoryToggle(
                        "Remove Archives",
                        detail: sizeFormatted(clearStore.usedSpace.archives),
                        isOn: $bindablePreferences.canRemoveArchives.value
                    )
                    
                    factoryToggle(
                        "Remove Caches",
                        detail: sizeFormatted(clearStore.usedSpace.cacheSize),
                        isOn: $bindablePreferences.canRemoveCaches.value
                    )
                    
                    factoryToggle(
                        "Remove Derived Data",
                        detail: sizeFormatted(clearStore.usedSpace.derivedData),
                        isOn: $bindablePreferences.canRemoveDerivedData.value
                    )
                }
                .tint(.green)
                
                Section {
                    factoryToggle(
                        "Clear Device Support",
                        detail: sizeFormatted(clearStore.usedSpace.deviceSupportSize),
                        isOn: $bindablePreferences.canClearDeviceSupport.value
                    )
                    
                    factoryToggle(
                        "Clear Simulator Data",
                        detail: sizeFormatted(clearStore.usedSpace.simulatorData),
                        isOn: $bindablePreferences.canClearSimultorData.value
                    )
                    
                    factoryToggle(
                        "Remove Old Simulators",
                        isOn: $bindablePreferences.canRemoveOldSimulators.value
                    )
                }
                .tint(.red)
                
                Section {
                    factoryToggle(
                        "Reset Xcode Preferences",
                        isOn: $bindablePreferences.canResertXcodePreferences.value
                    )
                }
                .tint(.orange)
                
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
        }
    }
    
    // MARK: - Private Methods
    
    private func sizeFormatted(_ size: Int) -> String {
        Double(size).byteFormatter()
    }
    
    @ViewBuilder
    private func factoryToggle(
        _ title: String,
        detail: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center) {
            Image(systemName: "info.circle")
                .resizable()
                .frame(width: 12, height: 12)
            
            Text(title)
            
            Spacer()
            
            if let detail {
                Text(detail)
                    .foregroundStyle(.placeholder)
            }
            
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }
    
}

#Preview {
    PreferencesView()
        .environment(\.clearStore, .init(.init(), analytics: Analytics()))
        .environment(\.preferences, .init())
        .environment(\.route, .init())
        .environment(\.analytics, .init())
}

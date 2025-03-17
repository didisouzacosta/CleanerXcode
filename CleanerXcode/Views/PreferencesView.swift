//
//  PreferencesView.swift
//  CleanerXcode
//
//  Created by Adriano Costa on 14/03/25.
//

import SwiftUI

struct PreferencesView: View {
    
    // MARK: - Environments
    
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
                Section("Permissions") {
                    Toggle("Remove Derived Data", isOn: $bindablePreferences.canRemoveDerivedData.value)
                    Toggle("Remove Caches", isOn: $bindablePreferences.canRemoveCaches.value)
                    Toggle("Remove Device Support", isOn: $bindablePreferences.canRemoveDeviceSupport.value)
                    Toggle("Remove Old Simulators", isOn: $bindablePreferences.canRemoveOldSimulators.value)
                }
                
                Section("Dedication") {
                    Text("This simple app was made for anyone who loves developing for Apple technologies.\n\nI'd like to dedicate this app to my son Orlando and my wife Gisele.")
                }
                
                Section("Social") {
                    VStack(spacing: 16) {
                        Text("If you like it, consider giving me a star on GitHub and following me on X and LinkedIn.")
                        
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
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        
                        Text("or make a donation.")
                        
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
    
}

#Preview {
    PreferencesView()
        .environment(\.preferences, .init())
        .environment(\.route, .init())
        .environment(\.analytics, .init())
}

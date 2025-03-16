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
                            Link(destination: .init(string: "https://github.com/didisouzacosta/CleanerXcode")!) {
                                Image("github.fill")
                            }
                            
                            Link(destination: .init(string: "https://x.com/didisouzacosta")!) {
                                Image("x-twitter")
                            }
                            
                            Link(destination: .init(string: "https://www.linkedin.com/in/adrianosouzacosta/")!) {
                                Image("linkedin")
                            }
                        }
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                        
                        Text("or make a donation.")
                        
                        Link(destination: .init(string: "https://buy.stripe.com/00gcN772R2ns3wA9AA")!) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.orange)
                                .overlay {
                                    Text("Donate")
                                        .font(.body)
                                }
                                .frame(height: 32)
                        }
                        .foregroundStyle(.primary)
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
}
